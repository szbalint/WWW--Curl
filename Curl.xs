
/*
 * Perl interface for libcurl. Check out the file README for more info.
 */

/*
 * Copyright (C) 2000, 2001, 2002, 2005, 2008 Daniel Stenberg, Cris Bailiff, et al.  
 * You may opt to use, copy, modify, merge, publish, distribute and/or 
 * sell copies of the Software, and permit persons to whom the 
 * Software is furnished to do so, under the terms of the MPL or
 * the MIT/X-derivate licenses. You may pick one of these licenses.
 */
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <curl/curl.h>
#include <curl/easy.h>
#include <curl/multi.h>

#define header_callback_func writeheader_callback_func

/* Do a favor for older perl versions */
#ifndef Newxz
#    define Newxz(v,n,t)                   Newz(0,v,n,t)
#endif

typedef enum {
    CALLBACK_WRITE = 0,
    CALLBACK_READ,
    CALLBACK_HEADER,
    CALLBACK_PROGRESS,
    CALLBACK_DEBUG,
    CALLBACK_LAST
} perl_curl_easy_callback_code;

typedef enum {
    SLIST_HTTPHEADER = 0,
    SLIST_QUOTE,
    SLIST_POSTQUOTE,
    SLIST_LAST
} perl_curl_easy_slist_code;


typedef struct {
    /* The main curl handle */
    struct CURL *curl;
    I32 *y;
    /* Lists that can be set via curl_easy_setopt() */
    struct curl_slist *slist[SLIST_LAST];
    SV *callback[CALLBACK_LAST];
    SV *callback_ctx[CALLBACK_LAST];

    /* copy of error buffer var for caller*/
    char errbuf[CURL_ERROR_SIZE+1];
    char *errbufvarname;
    I32 strings_index;
    char* strings[
	CURLOPT_LASTENTRY > CURLOPTTYPE_OFF_T ? CURLOPT_LASTENTRY - CURLOPTTYPE_OFF_T :
	CURLOPT_LASTENTRY > CURLOPTTYPE_FUNCTIONPOINT ? CURLOPT_LASTENTRY - CURLOPTTYPE_FUNCTIONPOINT :
	CURLOPT_LASTENTRY > CURLOPTTYPE_OBJECTPOINT ? CURLOPT_LASTENTRY - CURLOPTTYPE_OBJECTPOINT :
	CURLOPT_LASTENTRY
    ];

} perl_curl_easy;


typedef struct {
    struct curl_httppost * post;
    struct curl_httppost * last;
} perl_curl_form;

typedef enum {
    CALLBACKM_SOCKET = 0,
    CALLBACKM_TIMER,
    CALLBACKM_LAST,
} perl_curl_multi_callback_code;

typedef struct {
#ifdef __CURL_MULTI_H
    struct CURLM *curlm;

    SV *callback[CALLBACKM_LAST];
    SV *callback_ctx[CALLBACKM_LAST];

#else
    struct void *curlm;
#endif
} perl_curl_multi;

typedef enum {
    CALLBACKSH_LOCK = 0,
    CALLBACKSH_UNLOCK,
    CALLBACKSH_LAST,
} perl_curl_share_callback_code;

typedef struct {
    CURLSH *curlsh;

    SV *callback[CALLBACKSH_LAST];
    SV *callback_ctx[CALLBACKSH_LAST];
} perl_curl_share;


/* switch from curl option codes to the relevant callback index */
static perl_curl_easy_callback_code
callback_index(int option)
{
    switch(option) {
        case CURLOPT_WRITEFUNCTION:
        case CURLOPT_FILE:
            return CALLBACK_WRITE;
            break;

        case CURLOPT_READFUNCTION:
        case CURLOPT_INFILE:
            return CALLBACK_READ;
            break;

        case CURLOPT_HEADERFUNCTION:
        case CURLOPT_WRITEHEADER:
            return CALLBACK_HEADER;
            break;

        case CURLOPT_PROGRESSFUNCTION:
        case CURLOPT_PROGRESSDATA:
            return CALLBACK_PROGRESS;
            break;
	case CURLOPT_DEBUGFUNCTION:
	case CURLOPT_DEBUGDATA:
	   return CALLBACK_DEBUG;
	   break;
    }
    croak("Bad callback index requested\n");
    return CALLBACK_LAST;
}

/* switch from curl slist names to an slist index */
static perl_curl_easy_slist_code
slist_index(int option)
{
    switch(option) {
        case CURLOPT_HTTPHEADER:
            return SLIST_HTTPHEADER;
            break;
        case CURLOPT_QUOTE:
            return SLIST_QUOTE;
            break;
        case CURLOPT_POSTQUOTE:
            return SLIST_POSTQUOTE;
            break;
    }
    croak("Bad slist index requested\n");
    return SLIST_LAST;
}

static perl_curl_easy * perl_curl_easy_new()
{
    perl_curl_easy *self;
    Newz(1, self, 1, perl_curl_easy);
    self->curl=curl_easy_init();
    return self;
}

static perl_curl_easy * perl_curl_easy_duphandle(perl_curl_easy *orig)
{
    perl_curl_easy *self;
    Newz(1, self, 1, perl_curl_easy);
    self->curl=curl_easy_duphandle(orig->curl);
    return self;
}

static void perl_curl_easy_delete(perl_curl_easy *self)
{
    dTHX;
    perl_curl_easy_slist_code index;
    perl_curl_easy_callback_code i;
    
    if (self->curl) 
        curl_easy_cleanup(self->curl);

    *self->y = *self->y - 1;
    if (*self->y <= 0) {
    	for (index=0;index<SLIST_LAST;index++) {
            if (self->slist[index]) curl_slist_free_all(self->slist[index]);
        };
        Safefree(self->y);
    }
       	for(i=0;i<CALLBACK_LAST;i++) {
       	    sv_2mortal(self->callback[i]);
	}
	for(i=0;i<CALLBACK_LAST;i++) {
	    sv_2mortal(self->callback_ctx[i]);
	}


    if (self->errbufvarname)
        free(self->errbufvarname);
    for (i=0;i<=self->strings_index;i++) {
        if (self->strings[i] != NULL) {
	    char* ptr = self->strings[i];
            Safefree(ptr);
        }
    }
    Safefree(self);

}

/* Register a callback function */

static void perl_curl_easy_register_callback(perl_curl_easy *self, SV **callback, SV *function)
{
    dTHX;
    if (function && SvOK(function)) {	
	    /* FIXME: need to check the ref-counts here */
	    if (*callback == NULL) {
		*callback = newSVsv(function);
	    } else {
		SvSetSV(*callback, function);
	    }
    } else {
	    if (*callback != NULL) {
	    	sv_2mortal(*callback);
		*callback = NULL;
	    }
    }
}

#ifdef __CURL_MULTI_H
static void perl_curl_multi_register_callback(perl_curl_multi *self, SV **callback, SV *function)
{
    dTHX;
    if (function && SvOK(function)) {
	    /* FIXME: need to check the ref-counts here */
	    if (*callback == NULL) {
		*callback = newSVsv(function);
	    } else {
		SvSetSV(*callback, function);
	    }
    } else {
	    if (*callback != NULL) {
		sv_2mortal(*callback);
		*callback = NULL;
	    }
    }
}
#endif

#if (LIBCURL_VERSION_NUM>=0x070a03)
static void perl_curl_share_register_callback(perl_curl_share *self, SV **callback, SV *function)
{
    dTHX;
    if (function && SvOK(function)) {
	    /* FIXME: need to check the ref-counts here */
	    if (*callback == NULL) {
		*callback = newSVsv(function);
	    } else {
		SvSetSV(*callback, function);
	    }
    } else {
	    if (*callback != NULL) {
		sv_2mortal(*callback);
		*callback = NULL;
	    }
    }
}
#endif


/* start of form functions - very un-finished! */
static perl_curl_form * perl_curl_form_new()
{
    perl_curl_form *self;
    Newz(1, self, 1, perl_curl_form);
    self->post=NULL;
    self->last=NULL;
    return self;
}

static void perl_curl_form_delete(perl_curl_form *self)
{
    if (self->post) {
        curl_formfree(self->post);
    }
    Safefree(self);
}

/* make a new multi */
static perl_curl_multi * perl_curl_multi_new()
{
    perl_curl_multi *self;
    Newz(1, self, 1, perl_curl_multi);
#ifdef __CURL_MULTI_H
    self->curlm=curl_multi_init();
#else
    croak("curl version too old to support curl_multi_init()");
#endif
    return self;
}

/* delete the multi */
static void perl_curl_multi_delete(perl_curl_multi *self)
{
#ifdef __CURL_MULTI_H
    dTHX;
    perl_curl_multi_callback_code i;

    if (self->curlm) 
        curl_multi_cleanup(self->curlm);
    for(i=0;i<CALLBACKM_LAST;i++) {
        sv_2mortal(self->callback[i]);
        sv_2mortal(self->callback_ctx[i]);
    }

    Safefree(self);
#endif

}

/* make a new share */
static perl_curl_share * perl_curl_share_new()
{
    perl_curl_share *self;
    Newz(1, self, 1, perl_curl_share);
    self->curlsh=curl_share_init();
    return self;
}

/* delete the share */
static void perl_curl_share_delete(perl_curl_share *self)
{
    dTHX;
    perl_curl_share_callback_code i;
    if (self->curlsh) 
        curl_share_cleanup(self->curlsh);
    for(i=0;i<CALLBACKSH_LAST;i++) {
        sv_2mortal(self->callback[i]);
        sv_2mortal(self->callback_ctx[i]);
    }
    Safefree(self);
}

static size_t
write_to_ctx(pTHX_ SV* const call_ctx, const char* const ptr, size_t const n) {
    PerlIO *handle;
    SV* out_str;
    if (call_ctx) { /* a GLOB or a SCALAR ref */
        if(SvROK(call_ctx) && SvTYPE(SvRV(call_ctx)) <= SVt_PVMG) {
            /* write to a scalar ref */
            out_str = SvRV(call_ctx);
            if (SvOK(out_str)) {
                sv_catpvn(out_str, ptr, n);
            } else {
                sv_setpvn(out_str, ptr, n);
            }
            return n;
        }
        else {
            /* write to a filehandle */
            handle = IoOFP(sv_2io(call_ctx));
        }
    } else { /* punt to stdout */
        handle = PerlIO_stdout();
    }
   return PerlIO_write(handle, ptr, n);
}

/* generic fwrite callback, which decides which callback to call */
static size_t
fwrite_wrapper (
    const void *ptr,
    size_t size,
    size_t nmemb,
    perl_curl_easy *self,
    void *call_function,
    void *call_ctx)
{
    dTHX;
    if (call_function) { /* We are doing a callback to perl */
        dSP;
        int count, status;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);

        if (ptr) {
            XPUSHs(sv_2mortal(newSVpvn((char *)ptr, (STRLEN)(size * nmemb))));
        } else { /* just in case */
            XPUSHs(&PL_sv_undef);
        }
        if (call_ctx) {
            XPUSHs(sv_2mortal(newSVsv(call_ctx)));
        } else { /* should be a stdio glob ? */
           XPUSHs(&PL_sv_undef);
        }

        PUTBACK;
        count = perl_call_sv((SV *) call_function, G_SCALAR);
        SPAGAIN;

        if (count != 1)
            croak("callback for CURLOPT_WRITEFUNCTION didn't return a status\n");

        status = POPi;

        PUTBACK;
        FREETMPS;
        LEAVE;
        return status;

    } else {
        return write_to_ctx(aTHX_ call_ctx, ptr, size * nmemb);
    }
}

/* debug fwrite callback */
static size_t
fwrite_wrapper2 (
    const void *ptr,
    size_t size,
    perl_curl_easy *self,
    void *call_function,
    void *call_ctx,
    curl_infotype type)
{
    dTHX;
    dSP;

    if (call_function) { /* We are doing a callback to perl */
        int count, status;
        SV *sv;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);

        if (ptr) {
            XPUSHs(sv_2mortal(newSVpvn((char *)ptr, (STRLEN)(size * sizeof(char)))));
        } else { /* just in case */
            XPUSHs(&PL_sv_undef);
        }

        if (call_ctx) {
            XPUSHs(sv_2mortal(newSVsv(call_ctx)));
        } else { /* should be a stdio glob ? */
           XPUSHs(&PL_sv_undef);
        }

	XPUSHs(sv_2mortal(newSViv(type)));

        PUTBACK;
        count = perl_call_sv((SV *) call_function, G_SCALAR);
        SPAGAIN;

        if (count != 1)
            croak("callback for CURLOPT_*FUNCTION didn't return a status\n");

        status = POPi;

        PUTBACK;
        FREETMPS;
        LEAVE;
        return status;

    } else {
        return write_to_ctx(aTHX_ call_ctx, ptr, size * sizeof(char));
    }
}

/* Write callback for calling a perl callback */
static size_t
write_callback_func(const void *ptr, size_t size, size_t nmemb, void *stream)
{
    perl_curl_easy *self;
    self=(perl_curl_easy *)stream;
    return fwrite_wrapper(ptr,size,nmemb,self,
            self->callback[CALLBACK_WRITE],self->callback_ctx[CALLBACK_WRITE]);
}

/* header callback for calling a perl callback */
static size_t
writeheader_callback_func(const void *ptr, size_t size, size_t nmemb, void *stream)
{
    perl_curl_easy *self;
    self=(perl_curl_easy *)stream;

    return fwrite_wrapper(ptr,size,nmemb,self,
            self->callback[CALLBACK_HEADER],self->callback_ctx[CALLBACK_HEADER]);
}

/* debug callback for calling a perl callback */
static int
debug_callback_func(CURL* handle, curl_infotype type, char *ptr, size_t size, void *userptr)
{
    perl_curl_easy *self;
    self=(perl_curl_easy *)userptr;

    return fwrite_wrapper2(ptr,size,self,
            self->callback[CALLBACK_DEBUG],self->callback_ctx[CALLBACK_DEBUG],type);
}

/* read callback for calling a perl callback */
static size_t
read_callback_func( void *ptr, size_t size, size_t nmemb, void *stream)
{
    dTHX;
    dSP ;

    size_t maxlen;
    perl_curl_easy *self;
    self=(perl_curl_easy *)stream;

    maxlen = size*nmemb;

    if (self->callback[CALLBACK_READ]) { /* We are doing a callback to perl */
        char *data;
        int count;
        SV *sv;
        STRLEN len;

        ENTER ;
        SAVETMPS ;
 
        PUSHMARK(SP) ;

        if (self->callback_ctx[CALLBACK_READ]) {
            sv = self->callback_ctx[CALLBACK_READ];
        } else {
            sv = &PL_sv_undef;
        }

        XPUSHs(sv_2mortal(newSViv(maxlen)));
        XPUSHs(sv_2mortal(newSVsv(sv)));

        PUTBACK ;
        count = perl_call_sv(self->callback[CALLBACK_READ], G_SCALAR);
        SPAGAIN;

        if (count != 1)
            croak("callback for CURLOPT_READFUNCTION didn't return any data\n");

        sv = POPs;
        data = SvPV(sv,len);

        /* only allowed to return the number of bytes asked for */
        len = (len<maxlen ? len : maxlen);
        /* memcpy(ptr,data,(size_t)len); */
        Copy(data,ptr,len,char);

        PUTBACK ;
        FREETMPS ;
        LEAVE ;
        return (size_t) (len/size);

    } else {
        /* read input directly */
        PerlIO *f;
        if (self->callback_ctx[CALLBACK_READ]) { /* hope its a GLOB! */
            f = IoIFP(sv_2io(self->callback_ctx[CALLBACK_READ]));
        } else { /* punt to stdin */
           f = PerlIO_stdin();
        }
       return PerlIO_read(f,ptr,maxlen);
    }
}

/* Progress callback for calling a perl callback */

static int progress_callback_func(void *clientp, double dltotal, double dlnow,
    double ultotal, double ulnow)
{
    dTHX;
    dSP;

    int count;
    perl_curl_easy *self;
    self=(perl_curl_easy *)clientp;

    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    if (self->callback_ctx[CALLBACK_PROGRESS]) {
        XPUSHs(sv_2mortal(newSVsv(self->callback_ctx[CALLBACK_PROGRESS])));
    } else {
        XPUSHs(&PL_sv_undef);
    }
    XPUSHs(sv_2mortal(newSVnv(dltotal)));
    XPUSHs(sv_2mortal(newSVnv(dlnow)));
    XPUSHs(sv_2mortal(newSVnv(ultotal)));
    XPUSHs(sv_2mortal(newSVnv(ulnow)));
    
    PUTBACK;
    count = perl_call_sv(self->callback[CALLBACK_PROGRESS], G_SCALAR);
    SPAGAIN;

    if (count != 1)
        croak("callback for CURLOPT_PROGRESSFUNCTION didn't return 1\n");

    count = POPi;

    PUTBACK;
    FREETMPS;
    LEAVE;
    return count;
}


#if (LIBCURL_VERSION_NUM>=0x070a03)
static void lock_callback_func(CURL *easy, curl_lock_data data, curl_lock_access locktype, void *userp )
{
    dTHX;
    dSP;

    int count;
    perl_curl_easy *self;
    self=(perl_curl_easy *)userp;

    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    if (self->callback_ctx[CALLBACKSH_LOCK]) {
        XPUSHs(sv_2mortal(newSVsv(self->callback_ctx[CALLBACKSH_LOCK])));
    } else {
        XPUSHs(&PL_sv_undef);
    }
    XPUSHs(sv_2mortal(newSViv( data )));
    XPUSHs(sv_2mortal(newSViv( locktype )));

    PUTBACK;
    count = perl_call_sv(self->callback[CALLBACKSH_LOCK], G_SCALAR);
    SPAGAIN;

    if (count != 0)
        croak("callback for CURLSHOPT_LOCKFUNCTION didn't return void\n");

    PUTBACK;
    FREETMPS;
    LEAVE;
    return;
}

static void unlock_callback_func(CURL *easy, curl_lock_data data, void *userp )
{
    dTHX;
    dSP;

    int count;
    perl_curl_easy *self;
    self=(perl_curl_easy *)userp;

    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    if (self->callback_ctx[CALLBACKSH_LOCK]) {
        XPUSHs(sv_2mortal(newSVsv(self->callback_ctx[CALLBACKSH_LOCK])));
    } else {
        XPUSHs(&PL_sv_undef);
    }
    XPUSHs(sv_2mortal(newSViv( data )));

    PUTBACK;
    count = perl_call_sv(self->callback[CALLBACKSH_LOCK], G_SCALAR);
    SPAGAIN;

    if (count != 0)
        croak("callback for CURLSHOPT_UNLOCKFUNCTION didn't return void\n");

    PUTBACK;
    FREETMPS;
    LEAVE;
    return;
}
#endif

static int socket_callback_func(CURL *easy, curl_socket_t s, int what, void *userp, void *socketp )
{
    dTHX;
    dSP;

    int count;
    perl_curl_multi *self;
    self=(perl_curl_multi *)userp;

    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    if (self->callback_ctx[CALLBACKM_SOCKET]) {
        XPUSHs(sv_2mortal(newSVsv(self->callback_ctx[CALLBACKM_SOCKET])));
    } else {
        XPUSHs(&PL_sv_undef);
    }
    XPUSHs(sv_2mortal(newSVuv( s )));
    XPUSHs(sv_2mortal(newSViv( what )));

    PUTBACK;
    count = perl_call_sv(self->callback[CALLBACKM_SOCKET], G_SCALAR);
    SPAGAIN;

    if (count != 1)
        croak("callback for CURLMOPT_SOCKETFUNCTION didn't return 1\n");

    count = POPi;

    PUTBACK;
    FREETMPS;
    LEAVE;
    return count;
}

static int timer_callback_func(CURLM *multi, long timeout_ms, void *userp )
{
    dTHX;
    dSP;

    int count;
    perl_curl_multi *self;
    self=(perl_curl_multi *)userp;

    ENTER;
    SAVETMPS;
    PUSHMARK(sp);
    if (self->callback_ctx[CALLBACKM_TIMER]) {
        XPUSHs(sv_2mortal(newSVsv(self->callback_ctx[CALLBACKM_TIMER])));
    } else {
        XPUSHs(&PL_sv_undef);
    }
    XPUSHs(sv_2mortal(newSViv(timeout_ms)));

    PUTBACK;
    count = perl_call_sv(self->callback[CALLBACKM_TIMER], G_SCALAR);
    SPAGAIN;

    if (count != 1)
        croak("callback for CURLMOPT_TIMERFUNCTION didn't return 1\n");

    count = POPi;

    PUTBACK;
    FREETMPS;
    LEAVE;
    return count;
}


#include "const-defenums.h"
#include "const-c.inc"

typedef perl_curl_easy * WWW__Curl__Easy;

typedef perl_curl_form * WWW__Curl__Form;

typedef perl_curl_multi * WWW__Curl__Multi;

typedef perl_curl_share * WWW__Curl__Share;

MODULE = WWW::Curl    PACKAGE = WWW::Curl

INCLUDE: const-xs.inc

MODULE = WWW::Curl    PACKAGE = WWW::Curl          PREFIX = curl_

void
curl__global_cleanup()
    CODE:
        curl_global_cleanup();

MODULE = WWW::Curl    PACKAGE = WWW::Curl::Easy    PREFIX = curl_easy_

BOOT:
        curl_global_init(CURL_GLOBAL_ALL); /* FIXME: does this need a mutex for ithreads? */


PROTOTYPES: ENABLE

void
curl_easy_init(...)
    ALIAS:
        new = 1
    PREINIT:
        perl_curl_easy *self;
        char *sclass = "WWW::Curl::Easy";

    PPCODE:
        if (items>0 && !SvROK(ST(0))) {
           STRLEN dummy;
           sclass = SvPV(ST(0),dummy);
        }

        self=perl_curl_easy_new(); /* curl handle created by this point */
        ST(0) = sv_newmortal();
        sv_setref_pv(ST(0), sclass, (void*)self);
        SvREADONLY_on(SvRV(ST(0)));
	
	Newxz(self->y,1,I32);
	if (!self->y) { croak ("out of memory"); }
	(*self->y)++;
        /* configure curl to always callback to the XS interface layer */
        curl_easy_setopt(self->curl, CURLOPT_WRITEFUNCTION, write_callback_func);
        curl_easy_setopt(self->curl, CURLOPT_READFUNCTION, read_callback_func);
        
	/* set our own object as the context for all curl callbacks */
        curl_easy_setopt(self->curl, CURLOPT_FILE, self); 
        curl_easy_setopt(self->curl, CURLOPT_INFILE, self); 
        
	/* we always collect this, in case it's wanted */
        curl_easy_setopt(self->curl, CURLOPT_ERRORBUFFER, self->errbuf);

        XSRETURN(1);

void
curl_easy_duphandle(self)
    WWW::Curl::Easy self
    PREINIT:
        perl_curl_easy *clone;
        char *sclass = "WWW::Curl::Easy";
        perl_curl_easy_callback_code i;

    PPCODE:
        clone=perl_curl_easy_duphandle(self);
	clone->y = self->y;
	(*self->y)++;

        ST(0) = sv_newmortal();
        sv_setref_pv(ST(0), sclass, (void*)clone);
        SvREADONLY_on(SvRV(ST(0)));

        /* configure curl to always callback to the XS interface layer */

        curl_easy_setopt(clone->curl, CURLOPT_WRITEFUNCTION, write_callback_func);
        curl_easy_setopt(clone->curl, CURLOPT_READFUNCTION, read_callback_func);
	if (self->callback[callback_index(CURLOPT_HEADERFUNCTION)] || self->callback_ctx[callback_index(CURLOPT_WRITEHEADER)]) {
		curl_easy_setopt(clone->curl, CURLOPT_HEADERFUNCTION, header_callback_func);
		curl_easy_setopt(clone->curl, CURLOPT_WRITEHEADER, clone); 
	}

	if (self->callback[callback_index(CURLOPT_PROGRESSFUNCTION)] || self->callback_ctx[callback_index(CURLOPT_PROGRESSDATA)]) {
		curl_easy_setopt(clone->curl, CURLOPT_PROGRESSFUNCTION, progress_callback_func);
		curl_easy_setopt(clone->curl, CURLOPT_PROGRESSDATA, clone); 
	}
	
	if (self->callback[callback_index(CURLOPT_DEBUGFUNCTION)] || self->callback_ctx[callback_index(CURLOPT_DEBUGDATA)]) {
		curl_easy_setopt(clone->curl, CURLOPT_DEBUGFUNCTION, debug_callback_func);
		curl_easy_setopt(clone->curl, CURLOPT_DEBUGDATA, clone);
	}

        /* set our own object as the context for all curl callbacks */
        curl_easy_setopt(clone->curl, CURLOPT_FILE, clone); 
        curl_easy_setopt(clone->curl, CURLOPT_INFILE, clone); 
        curl_easy_setopt(clone->curl, CURLOPT_ERRORBUFFER, clone->errbuf);

        for(i=0;i<CALLBACK_LAST;i++) {
           perl_curl_easy_register_callback(clone,&(clone->callback[i]), self->callback[i]);
           perl_curl_easy_register_callback(clone,&(clone->callback_ctx[i]), self->callback_ctx[i]);
        };
	
	for (i=0;i<=self->strings_index;i++) {
		if (self->strings[i] != NULL) {
			clone->strings[i] = savepv(self->strings[i]);
			curl_easy_setopt(clone->curl, CURLOPTTYPE_OBJECTPOINT + i, clone->strings[i]);
		}
	}
	clone->strings_index = self->strings_index;
        XSRETURN(1);

char *
curl_easy_version(...)
    CODE:
        RETVAL=curl_version();
    OUTPUT:
        RETVAL

int
curl_easy_setopt(self, option, value, push=0)
        WWW::Curl::Easy self
        int option
        SV * value
        int push
    CODE:
        RETVAL=CURLE_OK;
        switch(option) {
            /* SV * to user contexts for callbacks - any SV (glob,scalar,ref) */
            case CURLOPT_FILE:
            case CURLOPT_INFILE:
                perl_curl_easy_register_callback(self,
                        &(self->callback_ctx[callback_index(option)]), value);
                break;
            case CURLOPT_WRITEHEADER:
		curl_easy_setopt(self->curl, CURLOPT_HEADERFUNCTION, SvOK(value) ? header_callback_func : NULL);
        	curl_easy_setopt(self->curl, option, SvOK(value) ? self : NULL);
                perl_curl_easy_register_callback(self,&(self->callback_ctx[callback_index(option)]),value);
                break;
            case CURLOPT_PROGRESSDATA:
		curl_easy_setopt(self->curl, CURLOPT_PROGRESSFUNCTION, SvOK(value) ? progress_callback_func : NULL);
        	curl_easy_setopt(self->curl, option, SvOK(value) ? self : NULL); 
                perl_curl_easy_register_callback(self,&(self->callback_ctx[callback_index(option)]), value);
                break;
            case CURLOPT_DEBUGDATA:
		curl_easy_setopt(self->curl, CURLOPT_DEBUGFUNCTION, SvOK(value) ? debug_callback_func : NULL);
        	curl_easy_setopt(self->curl, option, SvOK(value) ? self : NULL); 
                perl_curl_easy_register_callback(self,&(self->callback_ctx[callback_index(option)]), value);
                break;

            /* SV * to a subroutine ref */
            case CURLOPT_WRITEFUNCTION:
            case CURLOPT_READFUNCTION:
		perl_curl_easy_register_callback(self,&(self->callback[callback_index(option)]), value);
		break;
            case CURLOPT_HEADERFUNCTION:
		curl_easy_setopt(self->curl, option, SvOK(value) ? header_callback_func : NULL);
		curl_easy_setopt(self->curl, CURLOPT_WRITEHEADER, SvOK(value) ? self : NULL);
		perl_curl_easy_register_callback(self,&(self->callback[callback_index(option)]), value);
		break;
            case CURLOPT_PROGRESSFUNCTION:
        	curl_easy_setopt(self->curl, option, SvOK(value) ? progress_callback_func : NULL);
		curl_easy_setopt(self->curl, CURLOPT_PROGRESSDATA, SvOK(value) ? self : NULL);
		perl_curl_easy_register_callback(self,&(self->callback[callback_index(option)]), value);
		break;
            case CURLOPT_DEBUGFUNCTION:
		curl_easy_setopt(self->curl, option, SvOK(value) ? debug_callback_func : NULL);
		curl_easy_setopt(self->curl, CURLOPT_DEBUGDATA, SvOK(value) ? self : NULL);
		perl_curl_easy_register_callback(self,&(self->callback[callback_index(option)]), value);
		break;

            /* slist cases */
            case CURLOPT_HTTPHEADER:
            case CURLOPT_QUOTE:
            case CURLOPT_POSTQUOTE:
            {
                /* This is an option specifying a list, which we put in a curl_slist struct */
                AV *array = (AV *)SvRV(value);
                struct curl_slist **slist = NULL;
                int last = av_len(array);
                int i;

                /* We have to find out which list to use... */
                slist = &(self->slist[slist_index(option)]);

                /* free any previous list */
                if (*slist && !push) {
                    curl_slist_free_all(*slist);
                    *slist=NULL;
                }                                                                       
                /* copy perl values into this slist */
                for (i=0;i<=last;i++) {
                    SV **sv = av_fetch(array,i,0);
                    STRLEN len = 0;
                    char *string = SvPV(*sv, len);
                    if (len == 0) /* FIXME: is this correct? */
                        break;
                    *slist = curl_slist_append(*slist, string);
                }
                /* pass the list into curl_easy_setopt() */
                RETVAL = curl_easy_setopt(self->curl, option, *slist);
            };
            break;

            /* Pass in variable name for storing error messages. Yuck. */
            case CURLOPT_ERRORBUFFER:
            {
                STRLEN dummy;
                if (self->errbufvarname)
                    free(self->errbufvarname);
                self->errbufvarname = strdup((char *)SvPV(value, dummy));
            };
            break;

            /* tell curl to redirect STDERR - value should be a glob */
            case CURLOPT_STDERR:
                RETVAL = curl_easy_setopt(self->curl, option, PerlIO_findFILE( IoOFP(sv_2io(value)) ) );
                break;

            /* not working yet... */
            case CURLOPT_HTTPPOST:
                if (sv_derived_from(value, "WWW::Curl::Form")) {
                    WWW__Curl__Form wrapper;
                    IV tmp = SvIV((SV*)SvRV(value));
                    wrapper = INT2PTR(WWW__Curl__Form,tmp);
                    RETVAL = curl_easy_setopt(self->curl, option, wrapper->post);
                } else
                    croak("value is not of type WWW::Curl::Form"); 
                break;

            /* Curl share support from Anton Fedorov */
#if (LIBCURL_VERSION_NUM>=0x070a03)
	    case CURLOPT_SHARE:
		if (sv_derived_from(value, "WWW::Curl::Share")) {
		    WWW__Curl__Share wrapper;
		    IV tmp = SvIV((SV*)SvRV(value));
		    wrapper = INT2PTR(WWW__Curl__Share,tmp);
		    RETVAL = curl_easy_setopt(self->curl, option, wrapper->curlsh);
		} else
		    croak("value is not of type WWW::Curl::Share"); 
		break;
#endif
            /* default cases */
            default:
                if (option < CURLOPTTYPE_OBJECTPOINT) { /* A long (integer) value */
                    RETVAL = curl_easy_setopt(self->curl, option, (long)SvIV(value));
                }
		else if (option < CURLOPTTYPE_FUNCTIONPOINT) { /* An objectpoint - string */
			int string_index = option - CURLOPTTYPE_OBJECTPOINT;
			/* FIXME: Does curl really want NULL for empty strings? */
			STRLEN dummy = 0;
			/* Pre 7.17.0, the strings aren't copied by libcurl.*/
	           	char* pv = SvOK(value) ? SvPV(value, dummy) : "";
	           	I32 len = (I32)dummy;
	           	pv = savepvn(pv, len);
			if (self->strings[string_index] != NULL)
                            Safefree(self->strings[string_index]);
			self->strings[string_index] = pv;
			if (self->strings_index < string_index) self->strings_index = string_index;
			RETVAL = curl_easy_setopt(self->curl, option, SvOK(value) ? pv : NULL);
		}
#ifdef CURLOPTTYPE_OFF_T
		else if (option < CURLOPTTYPE_OFF_T) { /* A function - notreached? */
                    		croak("Unknown curl option of type function"); 
		}
		else { /* A LARGE file option using curl_off_t, handling larger than 32bit sizes without 64bit integer support */
                            if (SvOK(value) && looks_like_number(value)) {
                                STRLEN dummy = 0;
                                char* pv = SvPV(value, dummy);
                                char* pdummy;
                                RETVAL = curl_easy_setopt(self->curl, option, (curl_off_t) strtoll(pv,&pdummy,10));
                            } else {
                                RETVAL = 0;
                            }
		}
#endif
                ;
                break;
        };
    OUTPUT:
        RETVAL

int
internal_setopt(self, option, value)
    WWW::Curl::Easy self
    int option
    int value
    CODE:
        croak("internal_setopt no longer supported - use a callback\n");
        RETVAL = 0;
    OUTPUT:
       RETVAL

int
curl_easy_perform(self)
    WWW::Curl::Easy self
    CODE:
        /* perform the actual curl fetch */
        RETVAL = curl_easy_perform(self->curl);

    if (RETVAL && self->errbufvarname) {
        /* If an error occurred and a varname for error messages has been
          specified, store the error message. */
        SV *sv = perl_get_sv(self->errbufvarname, TRUE | GV_ADDMULTI);
        sv_setpv(sv, self->errbuf);
    }
    OUTPUT:
        RETVAL


SV *
curl_easy_getinfo(self, option, ... )
    WWW::Curl::Easy self
    int option
    CODE:
        switch (option & CURLINFO_TYPEMASK) {
            case CURLINFO_STRING:
            {
                char * vchar;
                curl_easy_getinfo(self->curl, option, &vchar);
                RETVAL = newSVpv(vchar,0);
                break;
            }
            case CURLINFO_LONG:
            {
                long vlong;
                curl_easy_getinfo(self->curl, option, &vlong);
                RETVAL = newSViv(vlong);
                break;
            }
            case CURLINFO_DOUBLE:
            {
                double vdouble;
                curl_easy_getinfo(self->curl, option, &vdouble);
                RETVAL = newSVnv(vdouble);
                break;
            }
#ifdef CURLINFO_SLIST
            case CURLINFO_SLIST:
            {
                struct curl_slist *vlist, *entry;
                AV *items = newAV();
                curl_easy_getinfo(self->curl, option, &vlist);
                if (vlist != NULL) {
                    entry = vlist;
                    while (entry) {
                        av_push(items, newSVpv(entry->data, 0));
                        entry = entry->next;
                    }
                    curl_slist_free_all(vlist);
                }
                RETVAL = newRV(sv_2mortal((SV *) items));
                break;
            }
#endif /* CURLINFO_SLIST */
            default: {
                RETVAL = newSViv(CURLE_BAD_FUNCTION_ARGUMENT);
                break;
            }
        }
        if (items > 2) 
            sv_setsv(ST(2),RETVAL);
    OUTPUT:
        RETVAL

char *
curl_easy_errbuf(self)
    WWW::Curl::Easy self
    CODE:
        RETVAL = self->errbuf;
    OUTPUT:
        RETVAL

int
curl_easy_cleanup(self)
    WWW::Curl::Easy self
    CODE:
       /* does nothing anymore - cleanup is automatic when a curl handle goes out of scope */
        RETVAL = 0;
    OUTPUT:
        RETVAL

void
curl_easy_DESTROY(self)
    WWW::Curl::Easy self
    CODE:
        perl_curl_easy_delete(self);

SV *
curl_easy_strerror(self, errornum)
        WWW::Curl::Easy self
        int errornum
    CODE:
	{
#if (LIBCURL_VERSION_NUM>=0x070C00)
	     const char * vchar = curl_easy_strerror(errornum);
#else
	     const char * vchar = "Unknown because curl_easy_strerror function not available}";
#endif
	     RETVAL = newSVpv(vchar,0);
	}
    OUTPUT:
        RETVAL

MODULE = WWW::Curl    PACKAGE = WWW::Curl::Form    PREFIX = curl_form_

void
curl_form_new(...)
    PREINIT:
        perl_curl_form *self;
        char *sclass = "WWW::Curl::Form";
    PPCODE:
        if (items>0 && !SvROK(ST(0))) {
           STRLEN dummy;
           sclass = SvPV(ST(0),dummy);
        }

        self=perl_curl_form_new();

        ST(0) = sv_newmortal();
        sv_setref_pv(ST(0), sclass, (void*)self);
        SvREADONLY_on(SvRV(ST(0)));

        XSRETURN(1);

void
curl_form_formadd(self,name,value)
    WWW::Curl::Form self
    char *name
    char *value
    CODE:
        curl_formadd(&(self->post),&(self->last),
            CURLFORM_COPYNAME,name,
            CURLFORM_COPYCONTENTS,value,
            CURLFORM_END); 

void
curl_form_formaddfile(self,filename,description,type)
    WWW::Curl::Form self
    char *filename
    char *description
    char *type
    CODE:
        curl_formadd(&(self->post),&(self->last),
            CURLFORM_FILE,filename,
            CURLFORM_COPYNAME,description,
            CURLFORM_CONTENTTYPE,type,
            CURLFORM_END); 

void
curl_form_DESTROY(self)
    WWW::Curl::Form self
    CODE:
        perl_curl_form_delete(self);

MODULE = WWW::Curl    PACKAGE = WWW::Curl::Multi    PREFIX = curl_multi_

void
curl_multi_new(...)
    PREINIT:
        perl_curl_multi *self;
        char *sclass = "WWW::Curl::Multi";
    PPCODE:
        if (items>0 && !SvROK(ST(0))) {
            STRLEN dummy;
            sclass = SvPV(ST(0),dummy);
        }

        self=perl_curl_multi_new();

        ST(0) = sv_newmortal();
        sv_setref_pv(ST(0), sclass, (void*)self);
        SvREADONLY_on(SvRV(ST(0)));

        XSRETURN(1);

void
curl_multi_add_handle(curlm, curl)
    WWW::Curl::Multi curlm
    WWW::Curl::Easy curl
    CODE:
#ifdef __CURL_MULTI_H
        curl_multi_add_handle(curlm->curlm, curl->curl);
#endif

void
curl_multi_remove_handle(curlm, curl)
    WWW::Curl::Multi curlm
    WWW::Curl::Easy curl
    CODE:
#ifdef __CURL_MULTI_H
        curl_multi_remove_handle(curlm->curlm, curl->curl);
#endif

void
curl_multi_info_read(self)
    WWW::Curl::Multi self
    PREINIT:
    	CURL *easy = NULL;
    	CURLcode res;
    	char *stashid;
	int queue;
    	CURLMsg *msg;
    PPCODE:
    	while ((msg = curl_multi_info_read(self->curlm, &queue))) {
	    if (msg->msg == CURLMSG_DONE) {
                easy=msg->easy_handle;
                res=msg->data.result;
		break;
	    }
	};
	if (easy) {
		curl_easy_getinfo(easy, CURLINFO_PRIVATE, &stashid);
		curl_multi_remove_handle(self->curlm, easy);
		XPUSHs(sv_2mortal(newSVpv(stashid,0)));
		XPUSHs(sv_2mortal(newSViv(res)));
	} else {
		XSRETURN_EMPTY;
	}

SV *
curl_multi_fdset(self)
    WWW::Curl::Multi self
    PREINIT:
        fd_set fdread;
        fd_set fdwrite;
        fd_set fdexcep;
        int maxfd;
        int i;
        AV *readset;
        AV *writeset;
        AV *excepset;
    PPCODE:
        FD_ZERO(&fdread);
        FD_ZERO(&fdwrite);
        FD_ZERO(&fdexcep);

        readset = newAV();
        writeset = newAV();
        excepset = newAV();
        curl_multi_fdset(self->curlm, &fdread, &fdwrite, &fdexcep, &maxfd);
        if ( maxfd != -1 ) {
            for (i=0;i <= maxfd;i++) {
                if (FD_ISSET(i, &fdread)) {
                    av_push(readset, newSViv(i));
                }
                if (FD_ISSET(i, &fdwrite)) {
                    av_push(writeset, newSViv(i));
                }
                if (FD_ISSET(i, &fdexcep)) {
                    av_push(excepset, newSViv(i));
                }
            }
        }
	XPUSHs(sv_2mortal(newRV(sv_2mortal((SV *) readset))));
	XPUSHs(sv_2mortal(newRV(sv_2mortal((SV *) writeset))));
	XPUSHs(sv_2mortal(newRV(sv_2mortal((SV *) excepset))));

void
curl_multi_fdset_vec(self)
    WWW::Curl::Multi self
    PREINIT:
        fd_set fdread;
        fd_set fdwrite;
        fd_set fdexcep;
        int maxfd;
        int i;
        int vecsize;
        unsigned char readset[ sizeof( fd_set ) ] = { 0 };
        unsigned char writeset[ sizeof( fd_set ) ] = { 0 };
        unsigned char excepset[ sizeof( fd_set ) ] = { 0 };
    PPCODE:
        FD_ZERO(&fdread);
        FD_ZERO(&fdwrite);
        FD_ZERO(&fdexcep);

        curl_multi_fdset(self->curlm, &fdread, &fdwrite, &fdexcep, &maxfd);
        vecsize = ( maxfd + 8 ) / 8;

        if ( maxfd != -1 ) {
            for (i=0;i <= maxfd;i++) {
                if (FD_ISSET(i, &fdread)) {
                    readset[ i / 8 ] |= 1 << ( i % 8 );
                }
                if (FD_ISSET(i, &fdwrite)) {
                    writeset[ i / 8 ] |= 1 << ( i % 8 );
                }
                if (FD_ISSET(i, &fdexcep)) {
                    excepset[ i / 8 ] |= 1 << ( i % 8 );
                }
            }
        }
	XPUSHs(sv_2mortal(newSVpvn(readset, vecsize)));
	XPUSHs(sv_2mortal(newSVpvn(writeset, vecsize)));
	XPUSHs(sv_2mortal(newSVpvn(excepset, vecsize)));

long
curl_multi_timeout(self)
    WWW::Curl::Multi self
    PREINIT:
        long timeout;
        CURLMcode ret;
    CODE:
        if ( curl_multi_timeout(self->curlm, &timeout) != CURLM_OK )
            croak( "curl_multi_timeout() didn't return CURLM_OK" );

        RETVAL = timeout;
    OUTPUT:
        RETVAL

int
curl_multi_setopt(self, option, value)
        WWW::Curl::Multi self
        int option
        SV * value
    CODE:
        RETVAL=0;
#ifdef __CURL_MULTI_H
        RETVAL=CURLM_OK;
        switch(option) {
            case CURLMOPT_SOCKETFUNCTION:
            case CURLMOPT_SOCKETDATA:
                curl_multi_setopt(self->curlm, CURLMOPT_SOCKETFUNCTION, SvOK(value) ? socket_callback_func : NULL);
                curl_multi_setopt(self->curlm, CURLMOPT_SOCKETDATA, SvOK(value) ? self : NULL);
                perl_curl_multi_register_callback(self,
			option == CURLMOPT_SOCKETDATA ? &(self->callback_ctx[CALLBACKM_SOCKET]) : &(self->callback[CALLBACKM_SOCKET]),
			value);
                break;
            case CURLMOPT_TIMERFUNCTION:
            case CURLMOPT_TIMERDATA:
                curl_multi_setopt(self->curlm, CURLMOPT_TIMERFUNCTION, SvOK(value) ? timer_callback_func : NULL);
                curl_multi_setopt(self->curlm, CURLMOPT_TIMERDATA, SvOK(value) ? self : NULL);
                perl_curl_multi_register_callback(self,
			option == CURLMOPT_TIMERDATA ? &(self->callback_ctx[CALLBACKM_TIMER]) : &(self->callback[CALLBACKM_TIMER]),
			value);
                break;

            /* default cases */
            default:
                if (option < CURLOPTTYPE_OBJECTPOINT) { /* A long (integer) value */
                    RETVAL = curl_multi_setopt(self->curlm, option, (long)SvIV(value));
                }
                else {
                    croak("Unknown curl multi option");
                }
                ;
                break;
        };
#endif
    OUTPUT:
        RETVAL


int
curl_multi_perform(self)
    WWW::Curl::Multi self
    PREINIT:
        int remaining;
    CODE:
#ifdef __CURL_MULTI_H
        while(CURLM_CALL_MULTI_PERFORM ==
            curl_multi_perform(self->curlm, &remaining));
	    RETVAL = remaining;
#endif
	OUTPUT:
		RETVAL

int
curl_multi_socket_action(self, sockfd=CURL_SOCKET_BAD, ev_bitmask=0)
    WWW::Curl::Multi self
    int sockfd;
    int ev_bitmask;
    PREINIT:
        int remaining;
    CODE:
#ifdef __CURL_MULTI_H
        while(CURLM_CALL_MULTI_PERFORM ==
            curl_multi_socket_action(self->curlm, (curl_socket_t) sockfd, ev_bitmask, &remaining));
        RETVAL = remaining;
#endif
	OUTPUT:
		RETVAL


void
curl_multi_DESTROY(self)
    WWW::Curl::Multi self
    CODE:
        perl_curl_multi_delete(self);

SV *
curl_multi_strerror(self, errornum)
        WWW::Curl::Multi self
        int errornum
    CODE:
	{
#if (LIBCURL_VERSION_NUM>=0x070C00)
	     const char * vchar = curl_multi_strerror(errornum);
#else
	     const char * vchar = "Unknown because curl_multi_strerror function not available}";
#endif
	     RETVAL = newSVpv(vchar,0);
	}
    OUTPUT:
        RETVAL

MODULE = WWW::Curl    PACKAGE = WWW::Curl::Share    PREFIX = curl_share_

PROTOTYPES: ENABLE

void
curl_share_new(...)
    PREINIT:
        perl_curl_share *self;
        char *sclass = "WWW::Curl::Share";
    PPCODE:
        if (items>0 && !SvROK(ST(0))) {
            STRLEN dummy;
            sclass = SvPV(ST(0),dummy);
        }

        self=perl_curl_share_new();

        ST(0) = sv_newmortal();
        sv_setref_pv(ST(0), sclass, (void*)self);
        SvREADONLY_on(SvRV(ST(0)));

        XSRETURN(1);

void
curl_share_DESTROY(self)
        WWW::Curl::Share self
    CODE:
        perl_curl_share_delete(self);

int
curl_share_setopt(self, option, value)
        WWW::Curl::Share self
        int option
        SV * value
    CODE:
        RETVAL=CURLE_OK;
#if (LIBCURL_VERSION_NUM>=0x070a03)
        switch(option) {
            /* slist cases */
            case CURLSHOPT_LOCKFUNC:
                curl_share_setopt(self->curlsh, CURLSHOPT_LOCKFUNC, SvOK(value) ? lock_callback_func : NULL);
                curl_share_setopt(self->curlsh, CURLSHOPT_USERDATA, SvOK(value) ? self : NULL);
                perl_curl_share_register_callback(self,&(self->callback[CALLBACKSH_LOCK]), value);
                break;
            case CURLSHOPT_UNLOCKFUNC:
                curl_share_setopt(self->curlsh, CURLSHOPT_UNLOCKFUNC, SvOK(value) ? unlock_callback_func : NULL);
                curl_share_setopt(self->curlsh, CURLSHOPT_USERDATA, SvOK(value) ? self : NULL);
                perl_curl_share_register_callback(self,&(self->callback[CALLBACKSH_UNLOCK]), value);
                break;
            case CURLSHOPT_USERDATA:
                perl_curl_share_register_callback(self,&(self->callback_ctx[CALLBACKSH_LOCK]), value);
                break;
            case CURLSHOPT_SHARE:
            case CURLSHOPT_UNSHARE:
                RETVAL = curl_share_setopt(self->curlsh, option, (long)SvIV(value));
                break;
            default:
                croak("Unknown curl share option");
                break;

        };
#else
        croak("curl_share_setopt not supported in your libcurl version");
#endif
    OUTPUT:
        RETVAL

SV *
curl_share_strerror(self, errornum)
        WWW::Curl::Share self
        int errornum
    CODE:
	{
#if (LIBCURL_VERSION_NUM>=0x070C00)
	     const char * vchar = curl_share_strerror(errornum);
#else
	     const char * vchar = "Unknown because curl_share_strerror function not available}";
#endif
	     RETVAL = newSVpv(vchar,0);
	}
    OUTPUT:
        RETVAL
