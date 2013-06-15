// do not #include overload.h
#define PERL_NO_GET_CONTEXT

static inline bool IsGV(SV *sv) { return SvTYPE(sv) == SVt_PVGV; }

static inline bool IsRAV(pTHX_ SV *sv)
{
    if (!SvROK(sv))
        return false;
    SV *r = SvRV(sv);

    return SvTYPE(r) == SVt_PVAV;
}

static inline bool Min(size_t a, size_t b) { return a < b ? a : b; }

namespace
{
    const char *overload_descriptions[] =
    {
        NULL, "array", "boolean", "number", "string/scalar",
    };

    bool xsp_match_arguments_offset(pTHX_ const Xsp::Plugin::Overload::Prototype& prototype,
                                   int required,
                                   bool allow_more, size_t offset)
    {
        dXSARGS;
        PUSHMARK(MARK); // restore the mark we implicitly popped in dMARK!
        int argc = items - int(offset);

        if (required != -1)
        {
            if ( allow_more && argc <  required)
                return false;
            if (!allow_more && argc != required)
                return false;
        }
        else if (argc < int(prototype.count))
            return false;

        size_t max = Min(prototype.count, size_t(argc)) + offset;
        for (size_t i = offset; i < max; ++i)
        {
            const char *p = prototype.args[i - offset];

            // everything is a string or a boolean
            if (p == XspPluginOverloadString ||
                p == XspPluginOverloadBool)
                continue;

            SV *t = ST(i);

            // want a number
            if (p == XspPluginOverloadNumber)
            {
                if (looks_like_number(aTHX_ t))
                    continue;
                else
                    return false;
            }

            // want an array reference
            if (p == XspPluginOverloadArray && IsRAV(aTHX_ t))
                continue;

            // want an object/package name, accept undef, too
            const char *class_name = p > XspPluginOverloadMax ? p : NULL;

            if (   !IsGV(t) && class_name
                && (   !SvOK(t)
                    || (   sv_isobject(t)
                        && sv_derived_from(t, class_name))))
                continue;

            // type clash: return false
            return false;
        }

        return true;
    }
}

namespace Xsp { namespace Plugin { namespace Overload
{
    bool xsp_match_arguments_skipfirst(pTHX_ const Prototype& prototype,
                                       int required /* = -1 */,
                                       bool allow_more /* = false */)
    {
        return xsp_match_arguments_offset(aTHX_ prototype, required,
                                          allow_more, 1);
    }

    bool xsp_match_arguments(pTHX_ const Prototype& prototype,
                             int required /* = -1 */,
                             bool allow_more /* = false */)
    {
        return xsp_match_arguments_offset(aTHX_ prototype, required,
                                          allow_more, 0);
    }

    void xsp_overload_error(pTHX_ const char* function,
                            Prototype* prototypes[])
    {
        dXSARGS;
        PUSHMARK(MARK); // probably not necessary
        SV* message = newSVpv("Availble methods:\n", 0);
        sv_2mortal(message);

        for (int j = 0; prototypes[j]; ++j)
        {
            Prototype* p = prototypes[j];

            sv_catpv(message, function);
            sv_catpv(message, "(");

            for (int i = 0; i < p->count; ++i)
            {
                if (p->args[i] < XspPluginOverloadMax)
                    sv_catpv(message, overload_descriptions[PTR2IV(p->args[i])]);
                else
                    sv_catpv(message, p->args[i]);

                if (i != p->count - 1)
                    sv_catpv(message, ", ");
            }

            sv_catpv(message, ")\n");
        }

        sv_catpvf(message, "unable to resolve overload for %s(", function);

        for (size_t i = 1; i < items; ++i)
        {
            SV* t = ST(i);
            const char* type;

            if (!SvOK(t))
                type = "undef";
            else if(sv_isobject(t))
                type = HvNAME(SvSTASH(SvRV(t)));
            else if (SvROK(t))
            {
                SV* r = SvRV(t);

                if (SvTYPE(r) == SVt_PVAV)
                    type = "array";
                else if (SvTYPE(r) == SVt_PVHV)
                    type = "hash";
                else
                    type = "reference";
            }
            else if (IsGV(t))
                type = "glob/handle";
            else if (looks_like_number(aTHX_ t))
                type = "number";
            else
                type = "scalar";

            sv_catpv (message, type);
            if (i != items -1)
                sv_catpv(message, ", ");
        }

        sv_catpv(message, ")");

        require_pv("Carp.pm");
        const char* argv[2]; argv[0] = SvPV_nolen(message); argv[1] = NULL;
        call_argv("Carp::croak", G_VOID|G_DISCARD, (char**) argv); \
    }
}}} // namespaces
