#ifndef OMPPARSER_OPENMPAST_H
#define OMPPARSER_OPENMPAST_H

#include <fstream>
#include <iostream>

#include "OpenMPKinds.h"
#include <vector>
#include <string>
#include <stdio.h>
#include <string.h>
#include <map>
#include <cassert>

using namespace std;

enum OpenMPBaseLang {
    Lang_C,
    Lang_Cplusplus,
    Lang_Fortran,
};

class SourceLocation {
    int line;
    int column;
    int getLine ( ) { return line; };
    int getColumn ( ) { return column; };

    SourceLocation* parent_construct;

    public:
    SourceLocation(int _line = 0, int _col = 0, SourceLocation* _parent_construct = NULL) : line(_line), column(_col), parent_construct(_parent_construct) { } ;
    void setParentConstruct(SourceLocation* _parent_construct) { parent_construct = _parent_construct; };
    SourceLocation* getParentConstruct() { return parent_construct; };

};

/**
 * The class or baseclass for all the clause classes. For all the clauses that only take 0 to multiple expression or
 * variables, we use this class to create objects. For all other clauses, which requires at least one parameters,
 * we will have an inherit class from this one, and the superclass contains fields for the parameters
 */
class OpenMPClause : public SourceLocation {
protected:
    OpenMPClauseKind kind;

    /* consider this is a struct of array, i.e.
     * the expression/localtionLine/locationColumn are the same index are one record for an expression and its location
     */
    std::vector<const char *> expressions;
    std::vector<const void *> expressionNodes;

    std::vector<SourceLocation> locations;

public:
    OpenMPClause(OpenMPClauseKind k, int _line = 0, int _col = 0) : SourceLocation(_line, _col), kind(k) {};

    OpenMPClauseKind getKind() { return kind; };

    // a list of expressions or variables that are language-specific for the clause, ompparser does not parse them,
    // instead, it only stores them as strings
    void addLangExpr(const char *expression, int line = 0, int col = 0) {
        //TODO: Here we need to do certain normlization, if an expression already exists, we ignore
        expressions.push_back(expression);
        locations.push_back(SourceLocation(line, col));
    };
    
std::vector<const char *>* getExpressions() { return &expressions; };

    virtual std::string toString();
    std::string expressionToString();
    virtual void generateDOT(std::ofstream&, int, int, std::string);
/*
    std::vector<const char *> &getExpressions() { return expressions; };

    std::string toString();*/
};

/**
 * The class for all the OpenMP directives
 */
class OpenMPDirective : public SourceLocation  {
protected:
    OpenMPDirectiveKind kind;
    OpenMPBaseLang lang;

    /* the map to store clauses of the directive, for each clause, we store a vector of OpenMPClause objects
     * since there could be multiple clause objects for those clauses that take parameters, e.g. reduction clause
     *
     * for those clauses just take no parameters, but may take some variables or expressions, we only need to have
     * one OpenMPClause object, e.g. shared, private.
     *
     * The design and use of this map should make sure that for any clause, we should only have one OpenMPClause object
     * for each instance of kind and full parameters
     */
    map<OpenMPClauseKind, vector<OpenMPClause *> *> clauses;

    /**
     *
     * This method searches the clauses map to see whether one or more OpenMPClause objects of the specified kind
     * parameters exist in the directive, if so it returns the objects that match.
     * @param kind clause kind
     * @param parameters clause parameters
     * @return
     */
    std::vector<OpenMPClause *> searchOpenMPClause(OpenMPClauseKind kind, int num, int * parameters);

    /**
     * Search and add a clause of kind and parameters specified by the variadic parameters.
     * This should be the only call used to add an OpenMPClause object.
     *
     * The method may simply create an OpenMPClause-subclassed object and return it. In this way, normalization will be
     * needed later on.
     *
     * Or the method may do the normalization while adding a clause.
     * it first searches the clauses map to see whether an OpenMPClause object
     * of the specified kind and parameters exists in the map. If so, it only return
     * that OpenMPClause object, otherwise, it should create a new OpenMPClause object and insert in the map
     *
     * NOTE: if only partial parameters are provided as keys to search for a clause, the function will only
     * return the first one that matches. Thus, the method should NOT be called with partial parameters of a specific clause
     * @param kind
     * @param parameters clause parameters, number of parameters should be determined by the kind
     * @return
     */
    OpenMPClause * addOpenMPClause(OpenMPClauseKind kind, int * parameters);

    /**
     * normalize all the clause of a specific kind
     * @param kind
     * @return
     */
    void * normalizeClause(OpenMPClauseKind kind);

    std::string trait_score;

public:
    OpenMPDirective(OpenMPDirectiveKind k, OpenMPBaseLang _lang = Lang_C, int _line = 0, int _col = 0) :
            SourceLocation(_line, _col), kind(k), lang(_lang) {};

    OpenMPDirectiveKind getKind() { return kind; };

    map<OpenMPClauseKind, std::vector<OpenMPClause *> *> *getAllClauses() { return &clauses; };

    std::vector<OpenMPClause *> *getClauses(OpenMPClauseKind kind) { return clauses[kind]; };

    std::string toString();

    /* generate DOT representation of the directive */
    void generateDOT(std::ofstream&, int, int, std::string);
    void generateDOT();
    std::string generatePragmaString(std::string _prefix = "#pragma omp ", std::string _beginning_symbol = "", std::string _ending_symbol = "", bool _output_score = false);
    // To call this method directly to add new clause, it can't be protected.
    OpenMPClause * addOpenMPClause(OpenMPClauseKind kind, ...);
    void setTraitScore(const char* _score) { trait_score = std::string(_score); };
    std::string getTraitScore () { return trait_score; };
};
//declare variant directive
class OpenMPDeclareVariantDirective : public OpenMPDirective {
protected:
    std::string variant_func_id;
public:
    OpenMPDeclareVariantDirective () : OpenMPDirective(OMPD_declare_variant) {};
    void setVariantFuncID (const char* _variant_func_id) { variant_func_id = std::string(_variant_func_id); };
    std::string getVariantFuncID () { return variant_func_id; };
};

//allocate directive
class OpenMPAllocateDirective : public OpenMPDirective {
protected:
    std::vector<const char*> allocate_list;
public:
    OpenMPAllocateDirective () : OpenMPDirective(OMPD_allocate) {};
    void addAllocateList (const char* _allocate_list) { allocate_list.push_back(_allocate_list); };
    std::vector<const char*>* getAllocateList () { return &allocate_list; };
};

// reduction clause
class OpenMPReductionClause : public OpenMPClause {

protected:
    OpenMPReductionClauseModifier modifier;     // modifier
    OpenMPReductionClauseIdentifier identifier; // identifier
    std::string user_defined_identifier;                // user defined identifier if it is used

public:
    OpenMPReductionClause() : OpenMPClause(OMPC_reduction) { }

    OpenMPReductionClause(OpenMPReductionClauseModifier _modifier,
                          OpenMPReductionClauseIdentifier _identifier) : OpenMPClause(OMPC_reduction),
                                         modifier(_modifier), identifier(_identifier), user_defined_identifier ("") { };

    OpenMPReductionClauseModifier getModifier() { return modifier; };

    OpenMPReductionClauseIdentifier getIdentifier() { return identifier; };

    void setUserDefinedIdentifier(char *identifier) { user_defined_identifier = std::string(identifier); };

    std::string getUserDefinedIdentifier() { return user_defined_identifier; };

    static OpenMPReductionClause * addReductionClause(OpenMPDirective *directive,  OpenMPReductionClauseModifier modifier, 
                  OpenMPReductionClauseIdentifier identifier, char * user_defined_identifier=NULL);

    std::string toString();
    void generateDOT(std::ofstream&, int, int, std::string);
};

// allocate
class OpenMPAllocateClause : public OpenMPClause {
protected:
    OpenMPAllocateClauseAllocator allocator; // Allocate allocator
    std::string user_defined_allocator;                         /* user defined value if it is used */

public:
    OpenMPAllocateClause(OpenMPAllocateClauseAllocator _allocator) :
            OpenMPClause(OMPC_allocate), allocator(_allocator), user_defined_allocator ("") { };

    OpenMPAllocateClauseAllocator getAllocator() { return allocator; };

    void setUserDefinedAllocator(char *_allocator) { user_defined_allocator = std::string(_allocator); }

    std::string getUserDefinedAllocator() { return user_defined_allocator; };

    static OpenMPAllocateClause * addAllocateClause(OpenMPDirective *directive, OpenMPAllocateClauseAllocator allocator);
    std::string toString();
    void generateDOT(std::ofstream&, int, int, std::string);
};
// allocator
class OpenMPAllocatorClause : public OpenMPClause {
protected:
    OpenMPAllocatorClauseAllocator allocator; // Allocate allocator
    std::string user_defined_allocator;                         /* user defined value if it is used */

public:
    OpenMPAllocatorClause(OpenMPAllocatorClauseAllocator _allocator) :
            OpenMPClause(OMPC_allocator), allocator(_allocator), user_defined_allocator ("") { };

    OpenMPAllocatorClauseAllocator getAllocator() { return allocator; };

    void setUserDefinedAllocator(char *_allocator) { user_defined_allocator = std::string(_allocator); }

    std::string getUserDefinedAllocator() { return user_defined_allocator; };

    static OpenMPAllocatorClause * addAllocatorClause(OpenMPDirective *directive, OpenMPAllocatorClauseAllocator allocator);
    std::string toString();
    void generateDOT(std::ofstream&, int, int, std::string);
};

// lastprivate Clause
class OpenMPLastprivateClause : public OpenMPClause {
protected:
    OpenMPLastprivateClauseModifier modifier; // lastprivate modifier
    std::string user_defined_modifier;        /* user defined value if it is used */

public:
    OpenMPLastprivateClause() : OpenMPClause(OMPC_lastprivate) { }

    OpenMPLastprivateClause(OpenMPLastprivateClauseModifier _modifier) :
            OpenMPClause(OMPC_lastprivate), modifier(_modifier), user_defined_modifier ("") { };

    OpenMPLastprivateClauseModifier getModifier() { return modifier; };

    void setUserDefinedModifier(char *_modifier) { user_defined_modifier = _modifier; }

    std::string getUserDefinedModifier() { return user_defined_modifier; };

    static OpenMPLastprivateClause* addLastprivateClause(OpenMPDirective *directive, OpenMPLastprivateClauseModifier modifier);

    std::string toString();
    void generateDOT(std::ofstream&, int, int, std::string);
};

// linear Clause
class OpenMPLinearClause : public OpenMPClause {
protected:
    OpenMPLinearClauseModifier modifier; // linear modifier
    std::string user_defined_modifier;        /* user defined value if it is used */
    std::string user_defined_step;

public:
    OpenMPLinearClause(OpenMPLinearClauseModifier _modifier) :
            OpenMPClause(OMPC_linear), modifier(_modifier), user_defined_modifier ("") { };

    OpenMPLinearClauseModifier getModifier() { return modifier; };

    void setUserDefinedModifier(char *_modifier) { user_defined_modifier = _modifier; };

    std::string getUserDefinedModifier() { return user_defined_modifier; };

    void setUserDefinedStep(const char *_step) { user_defined_step = _step; };

    std::string getUserDefinedStep() { return user_defined_step; };
    
    static OpenMPLinearClause* addLinearClause(OpenMPDirective *directive, OpenMPLinearClauseModifier modifier);

    std::string toString();
    //std::string expressionToString(bool);
    void generateDOT(std::ofstream&, int, int, std::string);

};

// dist_schedule Clause
class OpenMPDistscheduleClause : public OpenMPClause {

protected:
    OpenMPDistscheduleClauseKind dist_schedule_kind;     // kind
    std::string user_defined_kind;                // user defined identifier if it is used

public:
    OpenMPDistscheduleClause( ) : OpenMPClause(OMPC_dist_schedule) { }

    OpenMPDistscheduleClause(OpenMPDistscheduleClauseKind _dist_schedule_kind) : OpenMPClause(OMPC_dist_schedule), dist_schedule_kind(_dist_schedule_kind), user_defined_kind ("") { };

    OpenMPDistscheduleClauseKind getKind() { return dist_schedule_kind; };

    void setUserDefinedKind(char *dist_schedule_kind) { user_defined_kind = dist_schedule_kind; };

    std::string getUserDefinedKind() { return user_defined_kind; };

    std::string toString();

    void generateDOT(std::ofstream&, int, int, std::string);
};


// schedule Clause
class OpenMPScheduleClause : public OpenMPClause {

protected:
    OpenMPScheduleClauseModifier modifier1;     // modifier1
    OpenMPScheduleClauseModifier modifier2;     // modifier2
    OpenMPScheduleClauseKind schedulekind; // identifier
    std::string user_defined_kind;                // user defined identifier if it is used

public:
    OpenMPScheduleClause( ) : OpenMPClause(OMPC_schedule) { }

    OpenMPScheduleClause(OpenMPScheduleClauseModifier _modifier1, OpenMPScheduleClauseModifier _modifier2,
                          OpenMPScheduleClauseKind _schedulekind) : OpenMPClause(OMPC_schedule),
                                         modifier1(_modifier1),modifier2(_modifier2), schedulekind(_schedulekind), user_defined_kind ("") { };

    OpenMPScheduleClauseModifier getModifier1() { return modifier1; };
    OpenMPScheduleClauseModifier getModifier2() { return modifier2; };
    OpenMPScheduleClauseKind getKind() { return schedulekind; };

    void setUserDefinedKind(char *schedulekind) { user_defined_kind = schedulekind; };

    std::string getUserDefinedKind() { return user_defined_kind; };
    std::string toString();
    void generateDOT(std::ofstream&, int, int, std::string);
};

// OpenMP clauses with variant directives, such as WHEN and MATCH clauses.
class OpenMPVariantClause : public OpenMPClause {
protected:
    std::vector<OpenMPDirective*> construct_directives;
    std::string user_condition_expression;
    std::string isa_expression;
    std::string arch_expression;
    std::string extension_expression;
    OpenMPClauseContextVendor context_vendor_name = OMPC_CONTEXT_VENDOR_unspecified;
    std::string implementation_user_defined_expression;
    OpenMPClauseContextKind context_kind_name = OMPC_CONTEXT_KIND_unknown;


public:
    OpenMPVariantClause(OpenMPClauseKind _kind) : OpenMPClause(_kind) { };

    std::string getUserCondition() { return user_condition_expression; };
    void setUserCondition(const char* _user_condition_expression) { user_condition_expression = std::string(_user_condition_expression); };
    void addConstructDirective(OpenMPDirective* _construct_directive) { construct_directives.push_back(_construct_directive); };
    void setContextKind(OpenMPClauseContextKind _context_kind_name) { context_kind_name = _context_kind_name; };
    OpenMPClauseContextKind getContextKind() { return context_kind_name; };
    std::vector<OpenMPDirective*>* getConstructDirective() { return &construct_directives; };
    void setIsaExpression(const char* _isa_expression) { isa_expression = std::string(_isa_expression); };
    std::string getIsaExpression() { return isa_expression; };
    void setArchExpression(const char* _arch_expression) { arch_expression = std::string(_arch_expression); };
    std::string getArchExpression() { return arch_expression; };
    void setExtensionExpression(const char* _extension_expression) { extension_expression = std::string(_extension_expression); };
    std::string getExtensionExpression() { return extension_expression; };
    void setImplementationKind(OpenMPClauseContextVendor _context_vendor_name) { context_vendor_name = _context_vendor_name; };
    OpenMPClauseContextVendor getImplementationKind() { return context_vendor_name; };
    void setImplementationExpression(const char* _implementation_user_defined_expression) { implementation_user_defined_expression = _implementation_user_defined_expression; };
    std::string getImplementationExpression() { return implementation_user_defined_expression; };
    std::string toString();
    //void generateDOT(std::ofstream&, int, int, std::string);
};

// When Clause
class OpenMPWhenClause : public OpenMPVariantClause {
protected:
    OpenMPDirective* variant_directive; // variant directive inside the WHEN clause


public:
    OpenMPWhenClause() : OpenMPVariantClause(OMPC_when) { };
    OpenMPDirective* getVariantDirective() { return variant_directive; };
    void setVariantDirective(OpenMPDirective* _variant_directive) { variant_directive = _variant_directive; };

    static OpenMPClause * addWhenClause(OpenMPDirective* directive);
    //void generateDOT(std::ofstream&, int, int, std::string);
};

// Match Clause
class OpenMPMatchClause : public OpenMPVariantClause {
protected:

public:
    OpenMPMatchClause( ) : OpenMPVariantClause(OMPC_match) { };

    static OpenMPClause * addMatchClause(OpenMPDirective* directive);
    //void generateDOT(std::ofstream&, int, int, std::string);
};


// ProcBind Clause
class OpenMPProcBindClause : public OpenMPClause {

protected:
    OpenMPProcBindClauseKind proc_bind_kind; // proc_bind

public:
    OpenMPProcBindClause(OpenMPProcBindClauseKind _proc_bind_kind) :
            OpenMPClause(OMPC_proc_bind), proc_bind_kind(_proc_bind_kind) { };

    OpenMPProcBindClauseKind getProcBindClauseKind() { return proc_bind_kind; };
    std::string toString();
    //void addProcBindClauseKind(OpenMPProcBindClauseKind v);
};

// Bind Clause
class OpenMPBindClause : public OpenMPClause {

protected:
    OpenMPBindClauseKind bind_kind;

public:
    OpenMPBindClause(OpenMPBindClauseKind _bind_kind) :
            OpenMPClause(OMPC_bind), bind_kind(_bind_kind) { };

    OpenMPBindClauseKind getBindClauseKind() { return bind_kind; };
    //void addProcBindClauseKind(OpenMPProcBindClauseKind v);
};

// Default Clause
class OpenMPDefaultClause : public OpenMPClause {

protected:
    OpenMPDefaultClauseKind default_kind = OMPC_DEFAULT_unknown;
    OpenMPDirective* variant_directive = NULL; // variant directive inside the DEFAULT clause

public:
    OpenMPDefaultClause(OpenMPDefaultClauseKind _default_kind) : OpenMPClause(OMPC_default), default_kind(_default_kind) { };

    OpenMPDefaultClauseKind getDefaultClauseKind() {return default_kind; };

    OpenMPDirective* getVariantDirective() { return variant_directive; };
    void setVariantDirective(OpenMPDirective* _variant_directive) { variant_directive = _variant_directive; };

    static OpenMPClause * addDefaultClause(OpenMPDirective* directive);
    std::string toString();
    //void generateDOT(std::ofstream&, int, int, std::string);
};

// if Clause
class OpenMPIfClause : public OpenMPClause {

protected:
    OpenMPIfClauseModifier modifier; // linear modifier
    std::string user_defined_modifier;        /* user defined value if it is used */

public:
    OpenMPIfClause(OpenMPIfClauseModifier _modifier) :
            OpenMPClause(OMPC_if), modifier(_modifier), user_defined_modifier ("") { };

    OpenMPIfClauseModifier getModifier() { return modifier; };

    void setUserDefinedModifier(char *_modifier) { user_defined_modifier = _modifier; };


    std::string getUserDefinedModifier() { return user_defined_modifier; };
    
    static OpenMPIfClause* addifClause(OpenMPDirective *directive, OpenMPIfClauseModifier modifier);

    std::string toString();

    void generateDOT(std::ofstream&, int, int, std::string);
};

#ifdef __cplusplus
extern "C" {
#endif
    extern  OpenMPDirective * parseOpenMP(const char *, void * exprParse(const char * expr));
#ifdef __cplusplus
}
#endif

#endif //OMPPARSER_OPENMPAST_H
