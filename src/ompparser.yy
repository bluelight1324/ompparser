/* OpenMP C and C++ Grammar */
/* Author: Markus Schordan, 2003 */
/* Modified by Christian Biesinger 2006 for OpenMP 2.0 */
/* Modified by Chunhua Liao for OpenMP 3.0 and connect to OmpAttribute, 2008 */
/* Updated by Chunhua Liao for OpenMP 4.5,  2017 */
/* Updated by Chrisogonas for OpenMP 5.0, 2018 */

/*
To debug bison conflicts, use the following command line in the build tree

/bin/sh ../../../../sourcetree/config/ylwrap ../../../../sourcetree/src/frontend/Sab.h `echo ompparser.cc | sed -e s/cc$/hh/ -e s/cpp$/hpp/ -e s/cxx$/hxx/ -e s/c++$/h++/ -e s/c$/h/` y.output ompparser.output -- bison -y -d -r state
in the build tree
*/
%name-prefix "omp_"
%defines
%error-verbose

%{
/* DQ (2/10/2014): IF is conflicting with Boost template IF. */
#undef IF

#include <stdio.h>
#include <assert.h>
#include <iostream>
#include "OpenMPAttribute.h"
#include <string.h>
#include <cstring>

#ifdef _MSC_VER
  #undef IN
  #undef OUT
  #undef DUPLICATE
#endif

/* Parser - BISON */

/*the scanner function*/
extern int omp_lex(); 

/*A customized initialization function for the scanner, str is the string to be scanned.*/
extern void omp_lexer_init(const char* str);

/* Standalone omppartser */
extern void start_lexer(const char* input);
extern void end_lexer(void);
void CreateAllocator(string);

//The directive/clause that are being parsed
static OpenMPDirective* CurrentDirective = NULL;
static OpenMPClause * CurrentClause = NULL;

//! Initialize the parser with the originating SgPragmaDeclaration and its pragma text
// extern void omp_parser_init(SgNode* aNode, const char* str);

/*Treat the entire expression as a string for now
  Implemented in the scanner*/
extern void omp_parse_expr();

static int omp_error(const char*);

// The current AST annotation being built
// static OmpAttribute* ompattribute = NULL;

// The current OpenMP construct or clause type which is being parsed
// It is automatically associated with the current ompattribute
// Used to indicate the OpenMP directive or clause to which a variable list or an expression should get added for the current OpenMP pragma being parsed.
// static omp_construct_enum omptype = e_unknown;

// The context node with the pragma annotation being parsed
//
// We attach the attribute to the pragma declaration directly for now, 
// A few OpenMP directive does not affect the next structure block
// This variable is set by the prefix_parser_init() before prefix_parse() is called.
//Liao
//static SgNode* gNode;

static const char* orig_str; 

// The current expression node being generated 
//static SgExpression* current_exp = NULL;
bool b_within_variable_list  = false;  // a flag to indicate if the program is now processing a list of variables

// We now follow the OpenMP 4.0 standard's C-style array section syntax: [lower-bound:length] or just [length]
// the latest variable symbol being parsed, used to help parsing the array dimensions associated with array symbol
// such as a[0:n][0:m]
//static SgVariableSymbol* array_symbol;
//static SgExpression* lower_exp = NULL;
//static SgExpression* length_exp = NULL;
// check if the parsed a[][] is an array element access a[i][j] or array section a[lower:length][lower:length]
// 
static bool arraySection=true; 



%}

%locations

/* The %union declaration specifies the entire collection of possible data types for semantic values. these names are used in the %token and %type declarations to pick one of the types for a terminal or nonterminal symbol
corresponding C type is union name defaults to YYSTYPE.
*/

%union {  int itype;
          double ftype;
          const char* stype;
          void* ptype; /* For expressions */
        }

/*Some operators have a suffix 2 to avoid name conflicts with ROSE's existing types, We may want to reuse them if it is proper. 
  experimental BEGIN END are defined by default, we use TARGET_BEGIN TARGET_END instead. 
  Liao*/
%token  OMP PARALLEL IF NUM_THREADS ORDERED SCHEDULE STATIC DYNAMIC GUIDED RUNTIME SECTIONS SINGLE NOWAIT SECTION
        FOR MASTER CRITICAL BARRIER ATOMIC FLUSH TARGET UPDATE DIST_DATA BLOCK DUPLICATE CYCLIC
        THREADPRIVATE PRIVATE COPYPRIVATE FIRSTPRIVATE LASTPRIVATE SHARED DEFAULT NONE REDUCTION COPYIN 
        TASK TASKWAIT UNTIED COLLAPSE AUTO DECLARE DATA DEVICE MAP ALLOC TO FROM TOFROM PROC_BIND CLOSE SPREAD
        SIMD SAFELEN ALIGNED LINEAR UNIFORM INBRANCH NOTINBRANCH MPI MPI_ALL MPI_MASTER TARGET_BEGIN TARGET_END
        '(' ')' ',' ':' '+' '*' '-' '&' '^' '|' LOGAND LOGOR SHLEFT SHRIGHT PLUSPLUS MINUSMINUS PTR_TO '.'
        LE_OP2 GE_OP2 EQ_OP2 NE_OP2 RIGHT_ASSIGN2 LEFT_ASSIGN2 ADD_ASSIGN2
        SUB_ASSIGN2 MUL_ASSIGN2 DIV_ASSIGN2 MOD_ASSIGN2 AND_ASSIGN2 
        XOR_ASSIGN2 OR_ASSIGN2 DEPEND IN OUT INOUT MERGEABLE
        LEXICALERROR IDENTIFIER 
        READ WRITE CAPTURE SIMDLEN FINAL PRIORITY
        ATTR_SHARED ATTR_NONE ATTR_PARALLEL ATTR_MASTER ATTR_CLOSE ATTR_SPREAD
        MODIFIER_INSCAN MODIFIER_TASK MODIFIER_DEFAULT
        IDENTIFIER_PLUS IDENTIFIER_MINUS IDENTIFIER_MUL IDENTIFIER_BITAND IDENTIFIER_BITOR IDENTIFIER_BITXOR IDENTIFIER_LOGAND IDENTIFIER_LOGOR IDENTIFIER_MAX IDENTIFIER_MIN
        ALLOCATE DEFAULT_MEM_ALLOC LARGE_CAP_MEM_ALLOC CONST_MEM_ALLOC HIGH_BW_MEM_ALLOC LOW_LAT_MEM_ALLOC 
		CGROUP_MEM_ALLOC PTEAM_MEM_ALLOC THREAD_MEM_ALLOC
/*We ignore NEWLINE since we only care about the pragma string , We relax the syntax check by allowing it as part of line continuation */
%token <itype> ICONSTANT   
%token <stype> EXPRESSION ID_EXPRESSION EXPR_STRING ALLOCATOR
/* associativity and precedence */
%left '<' '>' '=' "!=" "<=" ">="
%left '+' '-'
%left '*' '/' '%'

/* nonterminals names, types for semantic values, only for nonterminals representing expressions!! not for clauses with expressions.
 */
%type <stype> expression
%type <itype> schedule_kind

/* start point for the parsing */
%start openmp_directive

%%

/* NOTE: We can't use the EXPRESSION lexer token directly. Instead, we have
 * to first call omp_parse_expr, because we parse up to the terminating
 * paren.
 */

openmp_directive : parallel_directive 
                 | for_directive
                 | for_simd_directive
                 | declare_simd_directive
                 | sections_directive
                 | single_directive
                 | parallel_for_directive
                 | parallel_for_simd_directive
                 | parallel_sections_directive
                 | task_directive
                 | master_directive
                 | critical_directive
                 | atomic_directive
                 | ordered_directive
                 | barrier_directive 
                 | taskwait_directive
                 | flush_directive
                 | threadprivate_directive
                 | section_directive
                 | target_directive
                 | target_data_directive
                 | simd_directive
                 ;

parallel_directive : /* #pragma */ OMP PARALLEL {
                       CurrentDirective = new OpenMPDirective(OMPD_parallel);
					   CurrentDirective->setLabel("PARALLEL");
                     }
                     parallel_clause_optseq 
                   ;

parallel_clause_optseq : /* empty */
                       | parallel_clause_seq
                       ;

parallel_clause_seq : parallel_clause
                    | parallel_clause_seq parallel_clause
                    | parallel_clause_seq ',' parallel_clause
                    ;

proc_bind_clause : PROC_BIND { 
                        CurrentClause = new OpenMPClause(OMPC_proc_bind);
                        CurrentDirective->addClause(CurrentClause);
						CurrentClause->setLabel("PROC_BIND");
                      } '(' clause_parameter ')'
                    ;

/*  follow the order in the 4.5 specification  */ 
parallel_clause : if_clause
                | num_threads_clause
                | default_clause
                | private_clause
                | firstprivate_clause
                | shared_clause
                | copyin_clause
                | reduction_clause
                | proc_bind_clause
                | allocate_clause
                ;

copyin_clause: COPYIN {
				CurrentClause = new OpenMPClause(OMPC_copyin);
				CurrentDirective->addClause(CurrentClause);
				CurrentClause->setLabel("COPYIN");
				} '(' var_list ')' {
				}
			  ;

for_directive : /* #pragma */ OMP FOR { 
                  // ompattribute = buildOmpAttribute(e_for,gNode,true); 
                  // omptype = e_for; 
                  // cur_omp_directive=omptype;
                }
                for_clause_optseq
              ;

for_clause_optseq: /* emtpy */
              | for_clause_seq
              ;

for_clause_seq: for_clause
              | for_clause_seq for_clause 
              | for_clause_seq ',' for_clause

/*  updated to 4.5 */
for_clause: private_clause
           | firstprivate_clause
           | lastprivate_clause
           | linear_clause
           | reduction_clause
           | schedule_clause
           | collapse_clause
           | ordered_clause
           | nowait_clause  
          ; 

/* use this for the combined for simd directive */
for_or_simd_clause : ordered_clause
           | schedule_clause
           | private_clause
           | firstprivate_clause
           | lastprivate_clause
           | reduction_clause
           | collapse_clause
           | unique_simd_clause
           | nowait_clause  
          ;

schedule_chunk_opt: /* empty */
                | ',' expression { 
                 }
                ; 

ordered_clause: ORDERED {
                      // ompattribute->addClause(e_ordered_clause);
                      // omptype = e_ordered_clause;
                } ordered_parameter_opt
               ;

ordered_parameter_opt: /* empty */
                | '(' expression ')' {
                   }
                 ;

schedule_clause: SCHEDULE '(' schedule_kind {
                      // ompattribute->addClause(e_schedule);
                      // ompattribute->setScheduleKind(static_cast<omp_construct_enum>($3));
                      // omptype = e_schedule; 
                    }
                    schedule_chunk_opt  ')' 
                 ;

collapse_clause: COLLAPSE {
                      // ompattribute->addClause(e_collapse);
                      // omptype = e_collapse;
                    } '(' expression ')' { 
                    }
                  ;
 
schedule_kind : STATIC  { /* $$ = e_schedule_static; */ }
              | DYNAMIC { /* $$ = e_schedule_dynamic; */ }
              | GUIDED  { /* $$ = e_schedule_guided; */ }
              | AUTO    { /* $$ = e_schedule_auto; */ }
              | RUNTIME { /* $$ = e_schedule_runtime; */ }
              ;

sections_directive : /* #pragma */ OMP SECTIONS { 
                       // ompattribute = buildOmpAttribute(e_sections,gNode, true); 
                     } sections_clause_optseq
                   ;

sections_clause_optseq : /* empty */
                       | sections_clause_seq
                       ;

sections_clause_seq : sections_clause
                    | sections_clause_seq sections_clause
                    | sections_clause_seq ',' sections_clause
                    ;

sections_clause : private_clause
                | firstprivate_clause
                | lastprivate_clause
                | reduction_clause
                | nowait_clause
                ;

section_directive : /* #pragma */  OMP SECTION { 
                      // ompattribute = buildOmpAttribute(e_section,gNode,true); 
                    }
                  ;

single_directive : /* #pragma */ OMP SINGLE { 
                     // ompattribute = buildOmpAttribute(e_single,gNode,true); 
                     // omptype = e_single; 
                   } single_clause_optseq
                 ;

single_clause_optseq : /* empty */
                     | single_clause_seq
                     ;

single_clause_seq : single_clause
                  | single_clause_seq single_clause
                  | single_clause_seq ',' single_clause
                  ;
nowait_clause: NOWAIT {
                  // ompattribute->addClause(e_nowait);
                }
              ;

single_clause : unique_single_clause
              | private_clause
              | firstprivate_clause
              | nowait_clause
              ;
unique_single_clause : COPYPRIVATE { 
                         // ompattribute->addClause(e_copyprivate);
                         // omptype = e_copyprivate; 
                       }
                       '(' {b_within_variable_list = true;} variable_list ')' {b_within_variable_list =false;}

task_directive : /* #pragma */ OMP TASK {
                    //curDirective = addDirective("task"); 
                    printf("direct task");
                 } task_clause_optseq
               ;

task_clause_optseq :  /* empty */ 
                   | task_clause_seq 
                   ; 

task_clause_seq    : task_clause {printf("task here. \n");}
                   | task_clause_seq task_clause
                   | task_clause_seq ',' task_clause
                   ;

task_clause : unique_task_clause
            | default_clause
            | private_clause
            | firstprivate_clause
            | shared_clause
            | depend_clause
            | if_clause
            ;

unique_task_clause : FINAL { 
                       // ompattribute->addClause(e_final);
                       // omptype = e_final; 
                     } '(' expression ')' { 
                     }
                   | PRIORITY { 
                       // ompattribute->addClause(e_priority);
                       // omptype = e_priority; 
                     } '(' expression ')' { 
                     }
                   | UNTIED {
                       // ompattribute->addClause(e_untied);
                     }
                   | MERGEABLE {
                       // ompattribute->addClause(e_mergeable);
                     }
                   ;
                   
depend_clause : DEPEND { 
                          // ompattribute->addClause(e_depend);
                        } '(' dependence_type ':' {b_within_variable_list = true; /* array_symbol=NULL; */ } expression ')'
                        {
                          // assert ((ompattribute->getVariableList(omptype)).size()>0); /* I believe that depend() must have variables */
                          b_within_variable_list = false;
                        }
                      ;

dependence_type : IN {
                       // ompattribute->setDependenceType(e_depend_in); 
                       // omptype = e_depend_in; /*variables are stored for each operator*/
                     }
                   | OUT {
                       // ompattribute->setDependenceType(e_depend_out);  
                       // omptype = e_depend_out;
                     }
                   | INOUT {
                       // ompattribute->setDependenceType(e_depend_inout); 
                       // omptype = e_depend_inout;
                      }
                   ;


parallel_for_directive : /* #pragma */ OMP PARALLEL FOR { 
                            CurrentDirective = new OpenMPDirective(OMPD_parallel_for);
							CurrentDirective->setLabel("PARALLEL_FOR");
                         } parallel_for_clauseoptseq
                       ;

parallel_for_clauseoptseq : /* empty */
                          | parallel_for_clause_seq
                          ;

/* tracking: change the order */
parallel_for_clause_seq : parallel_for_clause
                        | parallel_for_clause parallel_for_clause_seq
                        | parallel_for_clause ',' parallel_for_clause_seq
                        ;
/*
clause can be any of the clauses accepted by the parallel or for directives, except the
nowait clause, updated for 4.5.
*/
parallel_for_clause : if_clause
                    | num_threads_clause
                    | default_clause
                    | private_clause
                    | firstprivate_clause
                    | shared_clause
                    | copyin_clause
                    | reduction_clause
                    | proc_bind_clause
                    | lastprivate_clause
                    | linear_clause
                    | schedule_clause 
                    | collapse_clause
                    | ordered_clause
                    | allocate_clause
                   ;

allocate_clause : ALLOCATE {
                    CurrentClause = new OpenMPClause(OMPC_allocate);
                    CurrentDirective->addClause(CurrentClause);
					CurrentClause->setLabel("ALLOCATE");
                  } allocate_parameter
                ;

allocate_parameter : '(' var_list ')'
                        | '(' allocator_parameter ':' var_list ')'
                        ;
						
allocator_parameter : allocator_enum_parameter {}
					| user_defined_first_parameter
					;

user_defined_first_parameter : EXPR_STRING { 
							CurrentClause->setCustomFirstParameter($1);
							}
						  ;
							
allocator_enum_parameter : DEFAULT_MEM_ALLOC 		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_default_storage); }
						  | LARGE_CAP_MEM_ALLOC		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_large_capacity); }
						  | CONST_MEM_ALLOC 		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_constant_memory); }
						  | HIGH_BW_MEM_ALLOC 		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_high_bandwidth); }
						  | LOW_LAT_MEM_ALLOC 		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_low_latency); }	
						  | CGROUP_MEM_ALLOC 		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_group_access); }	
						  | PTEAM_MEM_ALLOC 		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_team_access); }
						  | THREAD_MEM_ALLOC 		{ CurrentClause->setAllocatorValue(OMPC_ALLOCATE_thread_access); }	
						;

parallel_for_simd_directive : /* #pragma */ OMP PARALLEL FOR SIMD { 
                           // ompattribute = buildOmpAttribute(e_parallel_for_simd, gNode, true); 
                           // omptype= e_parallel_for_simd;
                           // cur_omp_directive = omptype;
                         } parallel_for_simd_clauseoptseq
                       ;

parallel_for_simd_clauseoptseq : /* empty */
                          | parallel_for_simd_clause_seq

parallel_for_simd_clause_seq : parallel_for_simd_clause
                        | parallel_for_simd_clause_seq parallel_for_simd_clause
                        | parallel_for_simd_clause_seq ',' parallel_for_simd_clause
                          
parallel_for_simd_clause: copyin_clause
                    | ordered_clause
                    | schedule_clause
                    | unique_simd_clause
                    | default_clause
                    | private_clause
                    | firstprivate_clause
                    | lastprivate_clause
                    | reduction_clause
                    | collapse_clause
                    | shared_clause
                    | if_clause
                    | num_threads_clause
                    | proc_bind_clause
                   ; 
 
parallel_sections_directive : /* #pragma */ OMP PARALLEL SECTIONS { 
                                // ompattribute =buildOmpAttribute(e_parallel_sections,gNode, true); 
                                // omptype = e_parallel_sections; 
                                // cur_omp_directive = omptype;
                              } parallel_sections_clause_optseq
                            ;

parallel_sections_clause_optseq : /* empty */
                                | parallel_sections_clause_seq
                                ;

parallel_sections_clause_seq : parallel_sections_clause
                             | parallel_sections_clause_seq parallel_sections_clause
                             | parallel_sections_clause_seq ',' parallel_sections_clause
                             ;

parallel_sections_clause : copyin_clause
                         | default_clause
                         | private_clause
                         | firstprivate_clause
                         | lastprivate_clause
                         | shared_clause
                         | reduction_clause
                         | if_clause
                         | num_threads_clause
                         | proc_bind_clause
                         ;

master_directive : /* #pragma */ OMP MASTER { 
                     // ompattribute = buildOmpAttribute(e_master, gNode, true);
                     // cur_omp_directive = e_master; 
					}
                 ;

critical_directive : /* #pragma */ OMP CRITICAL {
                       // ompattribute = buildOmpAttribute(e_critical, gNode, true); 
                       // cur_omp_directive = e_critical;
                     } region_phraseopt
                   ;

region_phraseopt : /* empty */
                 | region_phrase
                 ;

/* This used to use IDENTIFIER, but our lexer does not ever return that:
 * Things that'd match it are, instead, ID_EXPRESSION. So use that here.
 * named critical section
 */
region_phrase : '(' ID_EXPRESSION ')' { 
                  // ompattribute->setCriticalName((const char*)$2);
                }
              ;

barrier_directive : /* #pragma */ OMP BARRIER { 
                      // ompattribute = buildOmpAttribute(e_barrier,gNode, true); 
                      // cur_omp_directive = e_barrier;
					}
                  ;

taskwait_directive : /* #pragma */ OMP TASKWAIT { 
                       // ompattribute = buildOmpAttribute(e_taskwait, gNode, true);  
                       // cur_omp_directive = e_taskwait;
                       }
                   ;

atomic_directive : /* #pragma */ OMP ATOMIC { 
                     // ompattribute = buildOmpAttribute(e_atomic,gNode, true); 
                     // cur_omp_directive = e_atomic;
                     } atomic_clauseopt
                 ;

atomic_clauseopt : /* empty */
                 | atomic_clause
                 ;

atomic_clause : READ { // ompattribute->addClause(e_atomic_clause);
                       // ompattribute->setAtomicAtomicity(e_atomic_read);
                      }
               | WRITE{ // ompattribute->addClause(e_atomic_clause);
                       // ompattribute->setAtomicAtomicity(e_atomic_write);
                  }

               | UPDATE { // ompattribute->addClause(e_atomic_clause);
                       // ompattribute->setAtomicAtomicity(e_atomic_update);
                  }
               | CAPTURE { // ompattribute->addClause(e_atomic_clause);
                       // ompattribute->setAtomicAtomicity(e_atomic_capture);
                  }
                ;
flush_directive : /* #pragma */ OMP FLUSH {
                    // ompattribute = buildOmpAttribute(e_flush,gNode, true);
                    // omptype = e_flush; 
                    // cur_omp_directive = omptype;
                  } flush_varsopt
                ;

flush_varsopt : /* empty */
              | flush_vars
              ;

flush_vars : '(' {b_within_variable_list = true;} variable_list ')' {b_within_variable_list = false;}
           ;

ordered_directive : /* #pragma */ OMP ORDERED { 
                      // ompattribute = buildOmpAttribute(e_ordered_directive,gNode, true); 
                      // cur_omp_directive = e_ordered_directive;
                    }
                  ;

threadprivate_directive : /* #pragma */ OMP THREADPRIVATE {
                            // ompattribute = buildOmpAttribute(e_threadprivate,gNode, true); 
                            // omptype = e_threadprivate; 
                            // cur_omp_directive = omptype;
                          } '(' {b_within_variable_list = true;} variable_list ')' {b_within_variable_list = false;}
                        ;

default_clause : DEFAULT { 
					CurrentClause = new OpenMPClause(OMPC_default);
					CurrentDirective->addClause(CurrentClause);
					CurrentClause->setLabel("DEFAULT");
				  } '(' clause_parameter ')'
				;

clause_parameter : ATTR_SHARED 		{ CurrentClause->setDefaultClauseValue(OMPC_DEFAULT_shared); }
                |  ATTR_NONE 		{ CurrentClause->setDefaultClauseValue(OMPC_DEFAULT_none); }
                |  ATTR_PARALLEL 	{ CurrentClause->setIfClauseValue(OMPC_IF_parallel); }
                |  ATTR_MASTER 		{ CurrentClause->setProcBindClauseValue(OMPC_PROC_BIND_master); }
                |  ATTR_CLOSE 		{ CurrentClause->setProcBindClauseValue(OMPC_PROC_BIND_close); }
                |  ATTR_SPREAD 		{ CurrentClause->setProcBindClauseValue(OMPC_PROC_BIND_spread); }
                ;
    
private_clause : PRIVATE {
                            CurrentClause = new OpenMPClause(OMPC_private);
                            CurrentDirective->addClause(CurrentClause);
							CurrentClause->setLabel("PRIVATE");
                            } '(' var_list ')' {
                            }
                          ;

firstprivate_clause : FIRSTPRIVATE { 
						CurrentClause = new OpenMPClause(OMPC_firstprivate);
						CurrentDirective->addClause(CurrentClause);
						CurrentClause->setLabel("FIRSTPRIVATE");
						} '(' var_list ')' {
						}
					  ;

lastprivate_clause : LASTPRIVATE { 
                                  // ompattribute->addClause(e_lastprivate); 
                                  // omptype = e_lastprivate;
                                } '(' {b_within_variable_list = true;} variable_list ')' {b_within_variable_list = false;}
                              ;

shared_clause : SHARED {
					CurrentClause = new OpenMPClause(OMPC_shared);
					CurrentDirective->addClause(CurrentClause);
					CurrentClause->setLabel("SHARED");
					} '(' var_list ')'
				  ;

reduction_clause : REDUCTION { 
                        CurrentClause = new OpenMPClause(OMPC_reduction);
                        CurrentDirective->addClause(CurrentClause);
						CurrentClause->setLabel("REDUCTION");
					} '(' reduction_parameter ':' var_list ')' {
					}
					;

reduction_parameter : reduction_identifier {}
					| reduction_modifier ',' reduction_identifier {}
					;

reduction_identifier : reduction_enum_identifier {	}
					| user_defined_first_parameter
				  ;
			  
reduction_modifier : MODIFIER_INSCAN 	{ CurrentClause->setReductionClauseModifier(OMPC_REDUCTION_MODIFIER_inscan); }
					| MODIFIER_TASK 	{ CurrentClause->setReductionClauseModifier(OMPC_REDUCTION_MODIFIER_task); }
					| MODIFIER_DEFAULT 	{ CurrentClause->setReductionClauseModifier(OMPC_REDUCTION_MODIFIER_default); }
					;

reduction_enum_identifier : IDENTIFIER_PLUS		{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_plus); }
						   | IDENTIFIER_MINUS	{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_minus); }
						   | IDENTIFIER_MUL		{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_mul); }
						   | IDENTIFIER_BITAND	{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_bitand); }
						   | IDENTIFIER_BITOR	{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_bitor); }
						   | IDENTIFIER_BITXOR	{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_bitxor); }
						   | IDENTIFIER_LOGAND	{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_logand); }
						   | IDENTIFIER_LOGOR	{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_logor); }
						   | IDENTIFIER_MAX		{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_max); }
						   | IDENTIFIER_MIN		{ CurrentClause->setReductionClauseIdentifier(OMPC_REDUCTION_IDENTIFIER_reduction_min); }
						;
						
expr_list : EXPR_STRING { CurrentClause->addLangExpr($1); }
        | expr_list ',' EXPR_STRING { CurrentClause->addLangExpr($3);}
        ;

var_list : EXPR_STRING { CurrentClause->addLangExpr($1); }
        | var_list ',' EXPR_STRING {
          CurrentClause->addLangExpr($3); }
        ;

target_data_directive: /* pragma */ OMP TARGET DATA {
                       // ompattribute = buildOmpAttribute(e_target_data, gNode,true);
                       // omptype = e_target_data;
                     }
                      target_data_clause_seq
                    ;

target_data_clause_seq : target_data_clause
                    | target_data_clause_seq target_data_clause
                    | target_data_clause_seq ',' target_data_clause
                    ;

target_data_clause : device_clause 
                | map_clause
                | if_clause
                ;

target_directive: /* #pragma */ OMP TARGET {
                       // ompattribute = buildOmpAttribute(e_target,gNode,true);
                       // omptype = e_target;
                       // cur_omp_directive = omptype;
                     }
                     target_clause_optseq 
                   ;

target_clause_optseq : /* empty */
                       | target_clause_seq
                       ;

target_clause_seq : target_clause
                    | target_clause_seq target_clause
                    | target_clause_seq ',' target_clause
                    ;

target_clause : device_clause 
                | map_clause
                | if_clause
                | num_threads_clause
                | begin_clause
                | end_clause
                ;
/*
device_clause : DEVICE {
                           ompattribute->addClause(e_device);
                           omptype = e_device;
                         } '(' expression ')' {
                           addExpression("");
                         }
                ;
*/

/* Experimental extensions to support multiple devices and MPI */
device_clause : DEVICE {
                           // ompattribute->addClause(e_device);
                           // omptype = e_device;
                         } '(' expression_or_star_or_mpi 
                ;
expression_or_star_or_mpi: 
                  MPI ')' { // special mpi device for supporting MPI code generation
                            // current_exp= SageBuilder::buildStringVal("mpi");
                          }
                  | MPI_ALL ')' { // special mpi device for supporting MPI code generation
                            // current_exp= SageBuilder::buildStringVal("mpi:all");
                          }
                  | MPI_MASTER ')' { // special mpi device for supporting MPI code generation
                            // current_exp= SageBuilder::buildStringVal("mpi:master");
                          }
                  | expression ')' { //normal expression
                          }
                  | '*' ')' { // our extension device (*) 
                            // current_exp= SageBuilder::buildCharVal('*'); 
                             }; 


begin_clause: TARGET_BEGIN {
                           // ompattribute->addClause(e_begin);
                           // omptype = e_begin;
                    }
                    ;

end_clause: TARGET_END {
                           // ompattribute->addClause(e_end);
                           // omptype = e_end;
                    }
                    ;
                   
if_clause: IF { 
                CurrentClause = new OpenMPClause(OMPC_if);
                CurrentDirective->addClause(CurrentClause);
				CurrentClause->setLabel("IF");
            } if_clause_parameter
         ;

// expr_list also takes a single expression
if_clause_parameter : '(' expr_list ')' 
				| '(' clause_parameter ':'  expr_list ')' 
				;

num_threads_clause: NUM_THREADS {
                            CurrentClause = new OpenMPClause(OMPC_num_threads);
                            CurrentDirective->addClause(CurrentClause);
							CurrentClause->setLabel("NUM_THREADS");
                         } '(' expr_list ')' {
                         }
                      ;
map_clause: MAP {
                          // ompattribute->addClause(e_map);
                           // omptype = e_map; // use as a flag to see if it will be reset later
                     } '(' map_clause_optseq 
                     { 
                       b_within_variable_list = true;
                       // if (omptype == e_map) // map data directions are not explicitly specified
                       {
                          // ompattribute->setMapVariant(e_map_tofrom);  omptype = e_map_tofrom;  
                       }
                     } 
                     map_variable_list ')' { b_within_variable_list =false;} 

map_clause_optseq: /* empty, default to be tofrom*/ { 
                 // ompattribute->setMapVariant(e_map_tofrom);  omptype = e_map_tofrom; /*No effect here???*/ 
}
                    | ALLOC ':' { 
// ompattribute->setMapVariant(e_map_alloc);  omptype = e_map_alloc; 
} 
                    | TO     ':' { 
// ompattribute->setMapVariant(e_map_to); omptype = e_map_to; 
} 
                    | FROM    ':' { 
// ompattribute->setMapVariant(e_map_from); omptype = e_map_from; 
} 
                    | TOFROM  ':' { 
// ompattribute->setMapVariant(e_map_tofrom); omptype = e_map_tofrom; 
} 
                    ;

for_simd_directive : /* #pragma */ OMP FOR SIMD { 
                  // ompattribute = buildOmpAttribute(e_for_simd, gNode,true); 
                  // cur_omp_directive = e_for_simd;
                }
                for_or_simd_clause_optseq
              ;


for_or_simd_clause_optseq:  /* empty*/
                      | for_or_simd_clause_seq
                      ;

simd_directive: /* # pragma */ OMP SIMD
                  { 
                    // ompattribute = buildOmpAttribute(e_simd,gNode,true); 
                    // omptype = e_simd; 
                    // cur_omp_directive = omptype;
                    }
                   simd_clause_optseq
                ;

simd_clause_optseq: /*empty*/
             | simd_clause_seq 
            ;

simd_clause_seq: simd_clause
               |  simd_clause_seq simd_clause 
               |  simd_clause_seq ',' simd_clause 
              ;

/* updated to 4.5 */
simd_clause: safelen_clause
           | simdlen_clause
           | linear_clause
           | aligned_clause
           | private_clause
           | lastprivate_clause
           | reduction_clause
           | collapse_clause
            ;


for_or_simd_clause_seq
                : for_or_simd_clause
                | for_or_simd_clause_seq for_or_simd_clause
                | for_or_simd_clause_seq ',' for_or_simd_clause
                ;

safelen_clause :  SAFELEN {
                        // ompattribute->addClause(e_safelen);
                        // omptype = e_safelen;
                      } '(' expression ')' {
                 }
                ; 

unique_simd_clause: safelen_clause
                | simdlen_clause
                | aligned_clause
                | linear_clause
                ;

simdlen_clause: SIMDLEN {
                          // ompattribute->addClause(e_simdlen);
                          // omptype = e_simdlen;
                          } '(' expression ')' {
                      } 
                  ;

declare_simd_directive: OMP DECLARE SIMD {
                        // ompattribute = buildOmpAttribute(e_declare_simd, gNode,true);
                        // cur_omp_directive = e_declare_simd;
                     }
                     declare_simd_clause_optseq
                     ;

declare_simd_clause_optseq : /* empty*/
                        | declare_simd_clause_seq
                        ;

declare_simd_clause_seq
                : declare_simd_clause
                | declare_simd_clause_seq declare_simd_clause
                | declare_simd_clause_seq ',' declare_simd_clause
                ; 

declare_simd_clause     : simdlen_clause
                | linear_clause
                | aligned_clause
                | uniform_clause
                | INBRANCH { 
// ompattribute->addClause(e_inbranch); omptype = e_inbranch; /*TODO: this is temporary, to be moved to declare simd */
}
                | NOTINBRANCH { 
// ompattribute->addClause(e_notinbranch); omptype = e_notinbranch; /*TODO: this is temporary, to be moved to declare simd */ 
}
              ;

uniform_clause : UNIFORM { 
                         // ompattribute->addClause(e_uniform);
                         // omptype = e_uniform; 
                       }
                       '(' {b_within_variable_list = true;} variable_list ')' {b_within_variable_list =false;}
                ;

aligned_clause : ALIGNED { 
                         // ompattribute->addClause(e_aligned);
                         // omptype = e_aligned; 
                       }
                       '(' {b_within_variable_list = true;} variable_list {b_within_variable_list =false;} aligned_clause_optseq ')'
               ;
aligned_clause_optseq: /* empty */
                        | aligned_clause_alignment
                        ;

aligned_clause_alignment: ':' expression { } 


linear_clause :  LINEAR { 
                         // ompattribute->addClause(e_linear);
                         // omptype = e_linear; 
                        }
                       '(' {b_within_variable_list = true;} variable_list {b_within_variable_list =false;}  linear_clause_step_optseq ')'
                ;

linear_clause_step_optseq: /* empty */
                        | linear_clause_step
                        ;

linear_clause_step: ':' expression { }

expression : EXPR_STRING

/*  in C
variable-list : identifier
              | variable-list , identifier 
*/

/* in C++ (we use the C++ version) */ 
variable_list : ID_EXPRESSION {  }
              | variable_list ',' ID_EXPRESSION {  }
              ;

/* map (array[lower:length][lower:length])  , not array references, but array section notations */
map_variable_list : id_expression_opt_dimension
              | map_variable_list ',' id_expression_opt_dimension
              ;
/* mapped variables may have optional dimension information */
id_expression_opt_dimension: ID_EXPRESSION {  } dimension_field_optseq
                           ;

/* Parse optional dimension information associated with map(a[0:n][0:m]) Liao 1/22/2013 */
dimension_field_optseq: /* empty */
                      | dimension_field_seq
                      ;
/* sequence of dimension fields */
dimension_field_seq : dimension_field
                    | dimension_field_seq dimension_field
                    ;

dimension_field: '[' expression { /* lower_exp = current_exp; */} 
                 ':' expression { /* length_exp = current_exp; */
                      // assert (array_symbol != NULL);
                      // SgType* t = array_symbol->get_type();
                      // bool isPointer= (isSgPointerType(t) != NULL );
                      // bool isArray= (isSgArrayType(t) != NULL);
                      // if (!isPointer && ! isArray )
                      {
                        std::cerr<<"Error. ompparser.yy expects a pointer or array type."<<std::endl;
                        // std::cerr<<"while seeing "<<t->class_name()<<std::endl;
                      }
                      // ompattribute->array_dimensions[array_symbol].push_back( std::make_pair (lower_exp, length_exp));
                      } 
                  ']'
               ;

%%
int yyerror(const char *s) {
    // SgLocatedNode* lnode = isSgLocatedNode(gNode);
    // assert (lnode);
    // printf("Error when parsing pragma:\n\t %s \n\t associated with node at line %d\n", orig_str, lnode->get_file_info()->get_line()); 
    printf(" %s!\n", s);
    assert(0);
    return 0; // we want to the program to stop on error
}

// Standalone ompparser
OpenMPDirective* parseOpenMP(const char* input) {
    
    printf("Start parsing...\n");
    
	cout << input << endl;
	
    start_lexer(input);
    int res = yyparse();
    end_lexer();
    
    return CurrentDirective;
}
