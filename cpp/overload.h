#ifndef _XSPP_PLUGIN_OVERLOAD_DECLARATION_H
#define _XSPP_PLUGIN_OVERLOAD_DECLARATION_H

#define XspPluginOverloadArray   ((const char*)1)
#define XspPluginOverloadBool    ((const char*)2)
#define XspPluginOverloadNumber  ((const char*)3)
#define XspPluginOverloadString  ((const char*)4)
#define XspPluginOverloadMax     ((const char*)5)

#define XSP_PLUGIN_OVERLOAD_BEGIN() \
    PUSHMARK(MARK); \
    int count; \
    if (false) \
        ;

#define XSP_PLUGIN_OVERLOAD_MESSAGE(FUNCTION, PROTOTYPES) \
    else \
        Xsp::Plugin::Overload::xsp_overload_error(aTHX_ #FUNCTION, PROTOTYPES);

#define XSP_PLUGIN_OVERLOAD_REDISPATCH(NEW_METHOD_NAME) \
    do { \
        count = call_method(#NEW_METHOD_NAME, GIMME_V); SPAGAIN; \
    } while(0)

#define XSP_PLUGIN_OVERLOAD_MATCH_VOID(METHOD) \
    else if(items == 1) \
        XSP_PLUGIN_OVERLOAD_REDISPATCH(METHOD);

#define XSP_PLUGIN_OVERLOAD_MATCH_ANY(METHOD) \
    else if(true) \
        XSP_PLUGIN_OVERLOAD_REDISPATCH(METHOD);

#define XSP_PLUGIN_OVERLOAD_MATCH_EXACT(PROTO, METHOD, REQUIRED) \
    else if(Xsp::Plugin::Overload::xsp_match_arguments_skipfirst(aTHX_ PROTO, REQUIRED, false)) \
        XSP_PLUGIN_OVERLOAD_REDISPATCH(METHOD);

#define XSP_PLUGIN_OVERLOAD_MATCH_MORE(PROTO, METHOD, REQUIRED) \
    else if(Xsp::Plugin::Overload::xsp_match_arguments_skipfirst(aTHX_ PROTO, REQUIRED, true)) \
        XSP_PLUGIN_OVERLOAD_REDISPATCH(METHOD);

namespace Xsp { namespace Plugin { namespace Overload
{
    struct Prototype
    {
        Prototype(const char **const proto,
                  const size_t proto_size )
            : args( proto ), count( proto_size ) { }

        const char **const args;
        const size_t count;
    };

    bool xsp_match_arguments(pTHX_ const Prototype& prototype,
                             int required = -1,
                             bool allow_more = false);
    bool xsp_match_arguments_skipfirst(pTHX_ const Prototype& p,
                                       int required,
                                       bool allow_more);
    void xsp_overload_error(pTHX_ const char *function,
                            Prototype *prototypes[]);
}}} // namespaces

#endif // _XSPP_PLUGIN_OVERLOAD_DECLARATION_H
