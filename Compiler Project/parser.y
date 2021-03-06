%{
#include "Definitions.h"
#include <sys/queue.h>

int yyerror(char*);
int yylex();

void default_value(int type);

struct Ast_node* astroot;
char name[20];
int type, size, no_of_elements, no_of_params, no_of_args, error_code = 0;
int int_stack_index = 0;
char tag;
struct Symbol *sym, *s1, *s2;
struct Symbol *currmethod;
union Value value;
struct Symbol *newsym;

int enableRetStuck = 1;

int whileTop=-1;
struct Symbol *while_stack[30];

int rtop = -1;
struct Symbol *rs[30];

int vtop = -1;
struct Symbol *vs[30];



struct Hash_Table Symbols_Table[SYM_TABLE_SIZE];
struct Hash_Table methods_table;

int curMethodID = 0;
struct Symbol *curMethod = NULL;
%}

%union {
  int yint;
  double ydou;
  char yid[100];
  char ystr[300];
  struct Ast_node* node;
}
		  

%token ADD SUB MUL DIV ASSIGN AND OR XOR LTE GTE EQ NEQ NOT
%token <yid> FUNC_ID ID
%token <yint> INT_CONST BOOL_CONST
%token <ydou> FLOAT_CONST
%token <ystr> STR_CONST 
%token IF ELSE ELIF LOOP SHOW TAKE RET VOID START INT DOUBLE STR BOOL ARR BREAK CONT NEWL HASH QUO SQUO BASL BASP

%type <node> program functions function function_name data_type params param_list param
%type <node> stmts_list stmt withSemcol withoutSemcol
%type <node> array_decl return_stmt func_call func_type
%type <node> loop conditional conditions else_stmt boolean bi_logic_cond rel_op op
%type <node> expr array_assign assign_stmt assignment args_list args id_list
%type <node> constant arr value

%%
program:                          functions START '{' stmts_list '}'
                                  {
                                    
                                    sym = makeSymbol("start",4,&value,0,'f',0,0);
                                    strcpy(sym->asm_name, "_source_start");
                                    add_method_to_table(sym);
                                    
                                    astroot = makeNode(astProgram, sym, $1, $4, NULL, NULL);
                                  }
                                  | /* EMPTY */
                                  {
                                    printf("Either Start function is not there or program is empty\n");
                                    astroot = makeNode(astEmptyProgram, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  ;

functions:                        functions function 
                                  {
                                    $$ = makeNode(astFunctions, NULL, $1, $2, NULL, NULL);
                                  }
                                  | /* EMPTY */
                                  {
                                    $$ = NULL;
                                  };

function:                         function_name '{' stmts_list '}' 
                                  {
                                    
                                    newsym = makeSymbol("", 0, &value, 0, 'f', 0, 0);
                                    
                                    $$ = makeNode(astFunction, NULL, $1, $3, NULL, NULL);
                                  };

function_name:                    data_type FUNC_ID '(' params ')' 
                                  {
                                    $$ = makeNode(astFunctionName, NULL, $1, $4, NULL, NULL);
                                    strcpy(name, "_");
                                    strcat(name, $2+1);

                                    for(int i=0; i<no_of_params; i++) {
                                      s1 = popV();
                                      s1->is_param = 1;
                                      switch(s1->type) {
                                        case 0:
                                        case 3:				
                                          if(s1->tag=='v') {
                                            strcat(name, "_int");						
                                          } else if(s1->tag=='a') {
                                            strcat(name, "_intArr");
                                          }						
                                        break;
                                        case 1:				
                                          if(s1->tag=='v') {
                                            strcat(name, "_doub");
                                          } else if(s1->tag=='a'){
                                            strcat(name, "_doubArr");
                                          }
                                        break;
                                        case 2:
                                          strcat(name, "_intArr");
                                          break;
                                      }
                                    }		
                                    s1 = popV();
                                    default_value(s1->type);
                                    sym = makeSymbol($2, s1->type, &value, s1->size, 'f', 0, no_of_params);
                                    add_method_to_table(sym);		
                                    strcpy(sym->asm_name, name);
                                  };

params:                           param_list 
                                  {
                                    $$ = $1;
                                  }
                                  | /* EMPTY */ 
                                  {
                                    $$ = NULL;
                                    no_of_params = 0;
                                  };

param_list:                       param_list ',' param 
                                  {
                                    $$ = makeNode(astParamList, NULL, $1, $3, NULL, NULL);
                                    no_of_params++;
                                  }
                                  | param
                                  {
                                    $$ = $1;
                                    no_of_params=1;
                                  };

stmts_list:                       stmt stmts_list 
                                  {
                                    $$ = makeNode(astStmtsList, NULL, $1, $2, NULL, NULL);
                                  }
                                  | /* EMPTY */ 
                                  {
                                    $$ = NULL;
                                  };

stmt:                             withSemcol ';' 
                                  {
                                    $$ = $1;
                                  }
                                  | withoutSemcol 
                                  {
                                    $$ = $1;
                                  };

withSemcol:                       param 
                                  {
                                    $$ = $1;
                                  }
                                  | assign_stmt
                                  {
                                    $$ = $1;
                                  }
                                  | array_decl 
                                  {
                                    $$ = $1;
                                  }
                                  | return_stmt 
                                  {
                                    $$ = $1;
                                  }
                                  | func_call 
                                  {
                                    $$ = $1;
                                  }
                                  | BREAK 
                                  {
                                    s1 = pop_while();
                                    if(s1) {
                                      push_while(makeSymbol("loop", 4, &value, 0, 0, 0, 0));
                                    } else {
                                      printf("ERROR! Break must be in a while loop\n");
                                      exit(1);
                                    }                        
                                    $$ = makeNode(astBreak, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | CONT 
                                  {
                                    s1 = pop_while();
                                    if(s1) {
                                      push_while(makeSymbol("loop", 4, &value, 0, 0, 0, 0));
                                    } else {
                                      printf("ERROR! Continue must be in a while loop\n");
                                      exit(1);
                                    }   
                                    $$ = makeNode(astContinue, NULL, NULL, NULL, NULL, NULL);
                                  };
                                  
withoutSemcol:                    loop 
                                  {
                                    $$ = $1;
                                  }
                                  | conditional
                                  {
                                    $$ = $1;
                                  };

assign_stmt:                      param assignment 
                                  {
                                    printf("assign_stmt\n");
                                    s1 = popV();
                                    s2 = popV();
                                    sym = NULL;
                                    if(s1->type == 4 || s2->type == 4) {
                                      printf("Error! No assignment for void types\n");
                                      error_code = 1;
                                    } else if(s1->type != s2->type) {
                                      printf("Error! LHS and RHS of assignment are not of matching data types\n");
                                      error_code = 1;
                                    } else {
                                      sym = makeSymbol(s2->name, s2->type, &value, s2->size, 'v', 1, 0);
                                    }
                                    $$ = makeNode(astAssignStmt, sym, $1, $2, NULL, NULL);

                                  }
                                  | arr assignment
                                  {
                                    s1 = popV();
                                    s2 = popV();
                                    if(s1->type == 4 || s2->type == 4) {
                                      printf("Error! No assignment for void types\n");
                                      error_code = 1;
                                    } else if(s1->type != s2->type) {
                                      printf("Error! LHS and RHS of assignment are not of matching data types\n");
                                      error_code = 1;
                                    }
                                    $$ = makeNode(astArrayAssignStmt, s2, $1, $2, NULL, NULL);
                                  };

loop:                             LOOP 
                                  {
                                    sym = makeSymbol("loop", 4, &value, 0, 0, 0, 0);
                                    push_while(sym);
                                  }
                                  '(' conditions ')' '{' stmts_list '}'
                                  {
                                    $$ = makeNode(astLoop, NULL, $4, $7, NULL, NULL);
                                    pop_while();
                                  };

conditional:                      IF '(' conditions ')' '{' stmts_list '}' else_stmt
                                  {
                                    $$ = makeNode(astConditional, NULL, $3, $6, $8, NULL);
                                  };

else_stmt:                        ELSE '{' stmts_list '}' 
                                  {
                                    $$ = makeNode(astElseStmt, NULL, $3, NULL, NULL, NULL);
                                  }
                                  | /* EMPTY */ 
                                  {
                                    $$ = NULL;
                                  };

conditions:                       boolean 
                                  {
                                    $$ = $1;
                                    s1 = popV();
                                    if(s1->type == 2 || s1->type == 4) {
                                      printf("Error! Type of %s not compatible for boolean operations\n", s1->name);
                                      error_code = 1;
                                    }
                                    pushV(s1);
                                  }
                                  | boolean bi_logic_cond conditions 
                                  {
                                    $$ = makeNode(astConditions, NULL, $1, $2, $3, NULL);
                                    s1 = popV();
                                    s2 = popV();
                                    if(s1->type == 2 || s1->type == 4) {
                                      type = 4;
                                      size = 0;
                                      printf("Error! Type of %s not compatible for arithmetic operations\n", s1->name);
                                      error_code = 1;
                                    }
                                    else if(s2->type == 2 || s2->type == 4) {
                                      type = 4;
                                      size = 0;
                                      printf("Error! Type of %s not compatible for arithmetic operations\n", s2->name);
                                      error_code = 1;
                                    }
                                    else {
                                      type = 0;
                                      size = 4;
                                    }
                                    pushV(makeSymbol("", type, &value, size, 'c', 0, 0));
                                  }
                                  | NOT conditions 
                                  {
                                    $$ = makeNode(astNotConditions, NULL, $2, NULL, NULL, NULL);
                                    s1 = popV();
                                    if(s1->type == 2 || s1->type == 4) {
                                      printf("Error! Type of %s not compatible for boolean operations\n", s1->name);
                                      error_code = 1;
                                    }
                                  };

boolean:                          boolean  rel_op  expr 
                                  {
                                    s1 = popV();
                                    s2 = popV();
                                    if(s1->type == 2 || s1->type == 4) {
                                      type = 4;
                                      size = 0;
                                      printf("Error! Type of %s not compatible for arithmetic operations\n", s1->name);
                                      error_code = 1;
                                    }
                                    else if(s2->type == 2 || s2->type == 4) {
                                      type = 4;
                                      size = 0;
                                      printf("Error! Type of %s not compatible for arithmetic operations\n", s2->name);
                                      error_code = 1;
                                    }
                                    else {
                                      type = 0;
                                      size = 4;
                                    }
                                    sym=makeSymbol("", type, &value, size, 'c', 0, 0);
                                    pushV(sym);
                                    $$ = makeNode(astBoolean, sym, $1, $2, $3, NULL);
                                  }
                                  | expr 
                                  {
                                    $$ = $1;
                                  };

return_stmt:                      RET expr 
                                  {

                                    /* Check if the type of currmethod and the return type (pop from stack) are same */

                                    $$ = makeNode(astReturnStmt, currmethod, $2, NULL, NULL, NULL);
                                    popV();
                                  };

array_decl:                       ARR '<' data_type ',' INT_CONST '>' ID array_assign 
                                  {
                                    s1 = vs[vtop];
                                    if(s1->type != 4) {
                                      s1 = vs[vtop-no_of_elements];
                                      if($5 != no_of_elements) {
                                        printf("Error! Number of elements declared and assigned are not matching\n");
                                        error_code = 1;
                                      }
                                      for(int i=0; i<no_of_elements; i++) {
                                        s2 = popV();
                                        if(s1->type != s2->type) {
                                          printf("Error! Type of the array and the element are not matching\n");
                                        }
                                      }
                                    }
                                    else {
                                        popV();
                                      }
                                      s1 = popV();
                                      default_value(s1->type);
                                      sym = makeSymbol($7, s1->type, &value, $5*4, 'a', $5, 0);
                                      add_variable_to_table(sym);
                                      sym->asm_location = 8 + int_stack_index*4;
                                      int_stack_index += $5;
                                      $$ = makeNode(astArrayDecl, sym, $3, $8, NULL, NULL);
                                  };

func_call:                        func_type '(' args_list ')' 
                                  {
                                    $$ = makeNode(astFuncCall, NULL, $1, $3, NULL, NULL);
                                    s1 = vs[vtop-no_of_args];
                                    if(strcmp(s1->func_name, "take")!=0 && strcmp(s1->func_name, "show")!=0 && s1!=NULL) {
                                      if(no_of_args != s1->no_of_params) {
                                        printf("The function %s expects %d parameters but got %d arguments\n",s1->func_name, s1->no_of_params, no_of_args);
                                        error_code = 1;
                                        type = 4;
                                        size = 0;
                                      }
                                      else {
                                        strcpy(name, "_");
                                        strcat(name, (s1->func_name)+1);
                                        for(int i=0; i<no_of_args; i++) {
                                          s2 = popV();
                                          switch(s2->type) {
                                          case 0:
                                          case 3:		
                                            if (s1->tag=='a') {
                                              strcat(name, "_intArr");
                                            } else {
                                              strcat(name, "_int");						
                                            } 	
                                          break;
                                          case 1:				
                                            if (s1->tag=='a') {
                                              strcat(name, "_doubArr");
                                            } else {
                                              strcat(name, "_doub");
                                            }
                                          break;
                                          case 2:
                                            strcat(name, "_intArr");
                                            break;
                                          }
                                        }
                                        s1 = popV();
                                        printf("%s %s\n",s1->asm_name, name);
                                        if(strcmp(s1->asm_name, name) != 0) {
                                          printf("The arguments of function %s are not matching with the function's parameter types\n", s1->name);
                                          error_code = 1;
                                          type = 4;
                                          size = 0;
                                        } else {
                                        type = s1->type;
                                        size = s1->size;
                                        } }
                                      sym = makeSymbol("", type, &value, size, s1->tag, 0, 0);
                                      pushV(sym);
                                    }
                                    else {
                                      int i;
                                      for(i=0; i<no_of_args; i++){
                                        popV();
                                      }
                                      sym = popV();
                                      sym->no_of_params = no_of_args;
                                    }
                                  };

func_type:                        SHOW 
                                  {
                                    default_value(0);
                                    sym = makeSymbol("show",4,&value,0,'f',0,0);
                                    pushV(sym);
                                    $$ = makeNode(astFuncShow, sym, NULL, NULL, NULL, NULL);
                                  }

args_list:                        args 
                                  {
                                    $$ = $1;
                                  }
                                  | /* EMPTY */ 
                                  {
                                    $$ = NULL;
                                    no_of_args = 0;
                                  };

args:                             args ',' expr 
                                  {
                                    $$ = makeNode(astArgs, NULL, $1, $3, NULL, NULL);
                                    no_of_args = no_of_args + 1;
                                  }
                                  | expr 
                                  {
                                    $$ = $1;
                                    no_of_args = 1;
                                  };

array_assign:                     ASSIGN '[' id_list ']'
                                  {
                                    $$ = makeNode(astArrayAssign, NULL, $3, NULL, NULL, NULL);
                                  }
                                  | /* EMPTY */ 
                                  {
                                    $$ = NULL;
                                    no_of_elements = 0;
                                    pushV(makeSymbol("", 4, &value, 0, 'v', 0, 0));
                                  };

id_list:                          id_list ',' constant 
                                  {
                                    $$ = makeNode(astIdList, NULL, $1, $3, NULL, NULL);
                                    no_of_elements++;
                                  }
                                  | constant 
                                  {
                                    $$ = $1;
                                    no_of_elements = 1;
                                  };

param:                            data_type ID 
                                  {
                                    default_value(type);
                                    s1 = popV();
                                    sym = makeSymbol($2, s1->type, &value, s1->size, 'v', 1, 0);
                                    add_variable_to_table(sym);
                                    pushV(sym);
                                    sym->asm_location = 8 + int_stack_index*4;
                                    int_stack_index++;
                                    $$ = makeNode(astParam, sym, $1, NULL, NULL, NULL);
                                  }

assignment:                       ASSIGN expr 
                                  {
                                    $$ = makeNode(astAssignment, NULL, $2, NULL, NULL, NULL);
                                  };

expr:                             expr op value 
                                  {
                                    s1 = popV();
                                    s2 = popV();
                                    if(s1->type == 2|| s1->type == 4) {
                                      type = (s1->type == 2) ? 2 : 4;
                                      size = 0;
                                      printf("Error! Type of %s not compatible for arithmetic operations\n", s1->name);
                                      error_code = 1;
                                    }
                                    else if(s2->type == 2 || s2->type == 4) {
                                      type = (s2->type == 2) ? 2 : 4;
                                      size = 0;
                                      printf("Error! Type of %s not compatible for arithmetic operations\n", s2->name);
                                      error_code = 1;
                                    }
                                    else {
                                    switch (s1->type) {
                                      case 3:
                                      case 0:
                                        if (s2->type == 0){
                                          type = 0;
                                          size = 4;
                                        } else if (s2->type == 1){
                                          type = 1;
                                          size = 8;
                                        }
                                      break;
                                      case 1:
                                        type = 1;
                                        size = 8;
                                      break;
                                      } 
                                    }
                                    sym = makeSymbol("", type, &value, size, 'c', 0, 0);
                                    pushV(sym);
                                    $$ = makeNode(astExpr, sym, $1, $2, $3, NULL);
                                  }
                                  | value
                                  {
                                    sym = vs[vtop];
                                    $$ = makeNode(astValue, sym, $1, NULL, NULL, NULL);
                                  };

value:                            func_call 
                                  {
                                    $$ = $1;
                                  }
                                  | constant 
                                  {
                                    $$ = $1;
                                  }
                                  | arr
                                  {
                                    $$ = $1;
                                  }; 

arr:                              ID '[' expr ']' 
                                  {
                                    sym = NULL;
                                    sym = find_variable($1); 
                                    sym->asmclass = 'm';
                                    if(sym==NULL) {
                                      printf("Error! Variable %s is not declared\n", $1);
                                      error_code = 1;
                                    }
                                    s1 = popV();
                                    if(s1->type != 0) {
                                      printf("Error! Expression for index array is not of integer type\n");
                                    }
                                    pushV(sym);
                                    $$ = makeNode(astArr, sym, $3, NULL, NULL, NULL);
                                  }
                                  | ID 
                                  {
                                    sym = NULL;
                                    sym = find_variable($1); 
                                    if(sym==NULL) {
                                      printf("Error! Variable %s is not declared\n", $1);
                                      error_code = 1;
                                    }
                                    pushV(sym);
                                    $$ = makeNode(astId, sym, NULL, NULL, NULL, NULL);
                                  }; 

data_type:                        INT 
                                  {
                                    $$ = makeNode(astInt, NULL, NULL, NULL, NULL, NULL);
                                    sym = makeSymbol("", 0, &value, 4, 'c', 0, 0);
                                    pushV(sym);
                                  }
                                  | BOOL 
                                  {
                                    $$ = makeNode(astBool, NULL, NULL, NULL, NULL, NULL);
                                    sym = makeSymbol("bool", 3, &value, 1, 'c', 0, 0);
                                    pushV(sym);
                                  }
                                  | STR 
                                  {
                                    $$ = makeNode(astStr, NULL, NULL, NULL, NULL, NULL);
                                    sym = makeSymbol("str", 2, &value, 0, 'c', 0, 0);
                                    pushV(sym);
                                  }
                                  | DOUBLE 
                                  {
                                    $$ = makeNode(astDouble, NULL, NULL, NULL, NULL, NULL);
                                    sym = makeSymbol("dou", 1, &value, 8, 'c', 0, 0);
                                    pushV(sym);
                                  }
                                  | VOID
                                  {
                                    $$ = makeNode(astVoid, NULL, NULL, NULL, NULL, NULL);
                                    sym = makeSymbol("void", 4, &value, 0, 'c', 0, 0);
                                    pushV(sym);
                                  };


op:                               ADD 
                                  {
                                    $$ = makeNode(astAdd, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | SUB 
                                  {
                                    $$ = makeNode(astSub, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | MUL 
                                  {
                                    $$ = makeNode(astMul, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | DIV
                                  {
                                    $$ = makeNode(astDiv, NULL, NULL, NULL, NULL, NULL);
                                  }; 

rel_op:                           LTE 
                                  {
                                    $$ = makeNode(astLte, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | GTE 
                                  {
                                    $$ = makeNode(astGte, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | '<' 
                                  {
                                    $$ = makeNode(astLt, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | '>' 
                                  {
                                    $$ = makeNode(astGt, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | EQ 
                                  {
                                    $$ = makeNode(astEq, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | NEQ
                                  {
                                    $$ = makeNode(astNeq, NULL, NULL, NULL, NULL, NULL);
                                  };

bi_logic_cond:                    AND 
                                  {
                                    $$ = makeNode(astAnd, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | OR 
                                  {
                                    $$ = makeNode(astOr, NULL, NULL, NULL, NULL, NULL);
                                  }
                                  | XOR
                                  {
                                    $$ = makeNode(astXor, NULL, NULL, NULL, NULL, NULL);
                                  };

constant:                         INT_CONST 
                                  {
                                    value.ivalue = $1;
                                    sym = makeSymbol("intConst", 0, &value, 4, 'c', 1, 0);
                                    add_variable_to_table(sym);
                                    $$ = makeNode(astIntConst, sym, NULL, NULL, NULL, NULL);
                                    pushV(sym);
                                  }
                                  | SUB INT_CONST 
                                  {
                                    value.ivalue = -$2;
                                    sym = makeSymbol("intConst", 0, &value, 4, 'c', 1, 0);
                                    add_variable_to_table(sym);
                                    $$ = makeNode(astIntConst, sym, NULL, NULL, NULL, NULL);
                                    pushV(sym);
                                  }
                                  | STR_CONST 
                                  {
                                    strcpy(value.yvalue, $1);
                                    sym = makeSymbol("strConst", 2, &value, 0, 'c', 1, 0);
                                    add_variable_to_table(sym);
                                    $$ = makeNode(astStrConst, sym, NULL, NULL, NULL, NULL);
                                  }
                                  | BOOL_CONST 
                                  {
                                    value.ivalue = $1;
                                    sym = makeSymbol("intConst", 3, &value, 4, 'c', 1, 0);
                                    add_variable_to_table(sym);
                                    $$ = makeNode(astBoolConst, sym, NULL, NULL, NULL, NULL);
                                    pushV(sym);
                                  }
                                  | FLOAT_CONST
                                  {
                                    value.dvalue = $1;
                                    sym = makeSymbol("doubleConst", 1, &value, 8, 'c', 1, 0);
                                    add_variable_to_table(sym);
                                    $$ = makeNode(astFloatConst, sym, NULL, NULL, NULL, NULL);
                                    pushV(sym);       
                                  }
                                  | SUB FLOAT_CONST
                                  {
                                    value.dvalue = -$2;
                                    sym = makeSymbol("doubleConst", 1, &value, 8, 'c', 1, 0);
                                    add_variable_to_table(sym);
                                    $$ = makeNode(astFloatConst, sym, NULL, NULL, NULL, NULL);
                                    pushV(sym);
                                  };

%%

int yyerror(char *s) {
  printf("\nError: %s\n",s);
  return 0;
}

void default_value(int type) {
  switch(type) {
    case 0:
      value.ivalue = 0;
      break;
    case 1:
      value.dvalue = 0;
      break;
    case 2:
      strcpy(value.yvalue, "");
      break;
    case 3:
      value.ivalue = 0;
  }
}

/* ------------------- Handling Hash Tables --------------- */

void Initialize_Tables(){
  for(int i=0;i<SYM_TABLE_SIZE;i++){
    methods_table.symbols[i] = NULL;
    for(int j=0;j<SYM_TABLE_SIZE;j++){
      Symbols_Table[i].symbols[j] = NULL;
    }
  }
}

void Print_Tables(){
  printf("------- Method Table ---------\n");
  printf("Function Name\tParams_count\tReturn Type\n");
  for(int i=0;i<SYM_TABLE_SIZE;i++){
    if(methods_table.symbols[i] != NULL) {
      struct Symbol* symb = methods_table.symbols[i];
      printf("%s\t\t%d\t\t",symb->func_name,symb->no_of_params);
      type = symb->type;
        switch(type) {
          case 0:
            printf("int\n");
            break;
          case 1:
            printf("double\n");
            break;
          case 2:
            printf("string\n");
            break;
          case 3:
            printf("boolean\n");
            break;
          case 4:
            printf("void\n");
        }
    }
  }
  printf("------- Symbol tables ---------\n");
  printf("Variable Name\t\tValue\t\tDatatype\n");
  for(int i=0;i<SYM_TABLE_SIZE;i++){
    for(int j=0;j<SYM_TABLE_SIZE;j++){
      if(Symbols_Table[i].symbols[j] != NULL) {
        struct Symbol* symb = Symbols_Table[i].symbols[j];
        while(symb != NULL) {
          printf("%s\t\t",symb->name);
          type = symb->type;
          switch(type) {
            case 0:
              printf("%d\t\tint\n",symb->value.ivalue);
              break;
            case 1:
              printf("%f\tdouble\n",symb->value.dvalue);
              break;
            case 2:
              printf("%s\t\tstring\n",symb->value.yvalue);
              break;
            case 3:
              printf("%d\t\tboolean\n",symb->value.ivalue);
          }
          symb = symb->next;
        }
      }
    }
  }
}

/* ------------------- Handling Hash Tables --------------- */

//Variable stack

void ShowVStack(){
	printf("\n--- VARIABLE STACK ---\n");
	for (int i=vtop; i>=0; i--){
		printf("%s %s %d %d %d\n", vs[i]->name, vs[i]->func_name, vs[i]->value.ivalue, vs[i]->type, vtop);
	}
	printf("--- END ---\n");
}

void pushV(struct Symbol *p)
{
  vs[++vtop]=p;
}

struct Symbol *popV()
{ 
  return(vs[vtop--]);
}

struct Symbol* reverse_pop(){

}

//Return Stack

void ShowRStack(){
	printf("\n--- RETURN STACK ---\n");
	for (int i=rtop; i>=0; i--){
		printf("%s\n", rs[i]->name);
	}
	printf("--- END ---\n");
}

void pushR(struct Symbol *p)
{
	rs[++rtop]=p;
}

struct Symbol *popR()
{
	return(rs[rtop--]);
}


int check_has_return(){
	
	struct Symbol *first, *second;
	
	first = rs[0];
	second = rs[1];
	
	
	if (rtop > 0 && first && second && strcmp(first->name, "start") == 0 && strcmp(second->name, "return") == 0){
		popR();
		popR();
		return 1;
	} else {
		return 0;
	}
	
}

//While Stack

struct Symbol* top_while() {
  return while_stack[whileTop];
}

void push_while(struct Symbol* whileSym) {
  while_stack[++whileTop] = whileSym;
}

struct Symbol *pop_while() {
	if (whileTop<0) {
		return(NULL);
	}

	struct Symbol * temp;
	temp = while_stack[whileTop--];
	while_stack[whileTop+1] = NULL;   
	return(temp);
}

void Init_While_Stack() {
	int i;
	for(i = 0; i < 30; i++) {
		while_stack[i] = NULL;
	}
}

void Show_While_Stack() {
	printf("\n--- WHILE STACK ---\n");
	for (int i = whileTop; i >= 0; i--) {
		printf("%s\n", while_stack[i]->name);
	}
	printf("--- END ---\n");
}

//Syntax

struct Ast_node* makeNode(int type, struct Symbol *sn, struct Ast_node* first, struct Ast_node* second, struct Ast_node* third, struct Ast_node* fourth){
  struct Ast_node * ptr = (struct Ast_node *)malloc(sizeof(struct Ast_node));
  ptr->node_type = type;
  ptr->symbol_node = sn;
  ptr->child_node[0] = first;
  ptr->child_node[1] = second;
  ptr->child_node[2] = third;
  ptr->child_node[3] = fourth;
  return ptr;
}

struct Symbol * makeSymbol(char *name, int type, union Value* value, int size,char tag,int no_elements,int no_of_params){
  struct Symbol* ptr = (struct Symbol*)malloc(sizeof(struct Symbol));
  ptr->tag = tag;
  if(tag == 'f'){
    strcpy(ptr->func_name, name);
  } else{
    strcpy(ptr->name, name);
  }
  switch(type) {
    case 0:
      ptr->value.ivalue = value->ivalue;
      break;
    case 1:
      ptr->value.dvalue = value->dvalue;
      break;
    case 2:
      strcpy(ptr->value.yvalue, value->yvalue);
      break;
    case 3:
      ptr->value.ivalue = value->ivalue;
      break;
    default:
      ptr->value.ivalue = 0;
      break;
  }
  strcpy(ptr->asm_name, "");
  ptr->asmclass = '\0';
  ptr->type = type;
  ptr->size = size;
  ptr->no_elements = no_elements;
  ptr->no_of_params = no_of_params;
  ptr->symbol_table = NULL;
  ptr->next = NULL;
  ptr->prev = NULL;
  return ptr;
}

void add_variable_to_table(struct Symbol *symbp)
{  
  struct Symbol *exists, *newsy;

  newsy=symbp;
  if(symbp->tag == 'c'){
    add_variable(newsy);
  }
  else{
	exists=find_variable(newsy->name);
	if( !exists )
	{
		add_variable(newsy);
  }else
  {
    printf("%s redeclaration.\n",newsy->name);
    exit(1);
  }
  }
}

void add_method_to_table(struct Symbol *symbp)
{  
  struct Symbol *exists, *newme;

  newme=symbp;
  
	exists=find_method(newme->func_name);
	if( !exists )
	{
		add_method(newme);
  }
  else
  {
      printf("%s redeclaration.\n",newme->func_name);
      exit(1);
  }
  currmethod = symbp;
}


int genKey(char *s)
{  
  char *p;
  int athr=0;
  for(p=s; *p; p++) athr=athr+(*p);
  return (athr % SYM_TABLE_SIZE);
}


void add_variable(struct Symbol *symbp)
{  
  int i;
  struct Symbol *ptr;
  
  i=genKey(symbp->name);
  
  ptr=Symbols_Table[curMethodID].symbols[i];
  symbp->next=ptr;
  symbp->prev=NULL;
  
  if(ptr) ptr->prev=symbp;
  Symbols_Table[curMethodID].symbols[i]=symbp;
  Symbols_Table[curMethodID].numbSymbols++;
}

struct Symbol *find_variable(char *s)
{  
  int i;
  struct Symbol *ptr;
  
  struct Hash_Table cur_table = Symbols_Table[curMethodID];

  i = genKey(s);
  ptr = cur_table.symbols[i];
  
  
  while(ptr && (strcmp(ptr->name,s) !=0))
    ptr=ptr->next;
  return ptr;
}

void add_method(struct Symbol *symbp)
{  
  int i;
  struct Symbol *ptr;

  i = genKey(symbp->func_name);
  ptr = methods_table.symbols[i];
  symbp->next = ptr;
  symbp->prev = NULL;
  symbp->symbol_table = &Symbols_Table[curMethodID];
  if(ptr) ptr->prev = symbp;
  methods_table.symbols[i] = symbp;
  methods_table.numbSymbols++;
  
  curMethod = symbp;
  
}

struct Symbol *find_method(char *s)
{  
  int i;
  struct Symbol *ptr;

  i = genKey(s);
  ptr = methods_table.symbols[i];
  
  while(ptr && (strcmp(ptr->func_name,s) !=0))
    ptr = ptr->next;
  return ptr;
}