%{
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "opts.h"
#include "dmalloc.h"
#include "lisp.h"
#include "X86_register.h"

obj* breakpoints=NULL;
char* load_filename=NULL;

static void add_new_BP (BP* bp)
{
    if (breakpoints==NULL)
        breakpoints=cons (create_obj_opaque(bp, (void(*)(void*))dump_BP, (void(*)(void*))BP_free), NULL);
    else
        breakpoints=nconc(breakpoints, create_obj_opaque(bp, (void(*)(void*))dump_BP, (void(*)(void*))BP_free));
};

%}

%union 
{
    char * str;
    int num;
    double dbl;
    struct _obj * o;
    struct _bp_address *a;
    struct _BPM *bpm;
    struct _BP *bp;
    struct _BPX_option *bpx_option;
    X86_register x86reg;
}

%token COMMA PLUS TWO_POINTS R_SQUARE_BRACKET SKIP COLON EOL BYTEMASK BYTEMASK_END BPX_EQ BPF_EQ
%token W RW _EOF DUMP_OP SET_OP COPY_OP CP QUOTE PERCENT BPF_CC BPF_PAUSE BPF_RT_PROBABILITY
%token BPF_TRACE BPF_TRACE_COLON
%token BPF_ARGS BPF_DUMP_ARGS BPF_RT BPF_SKIP BPF_SKIP_STDCALL BPF_UNICODE 
%token WHEN_CALLED_FROM_ADDRESS WHEN_CALLED_FROM_FUNC
%token <num> DEC_NUMBER HEX_NUMBER HEX_BYTE
%token <num> BPM_width CSTRING_BYTE
%token <x86reg> REGISTER
%token <dbl> FLOAT_NUMBER
%token <str> FILENAME_EXCLAMATION SYMBOL_NAME SYMBOL_NAME_PLUS LOAD_FILENAME

%type <a> address
%type <o> bytemask bytemask_element BPX_options cstring
%type <num> skip_n DEC_OR_HEX abs_address
%type <bp> bpm bpx
%type <bpx_option> BPX_option
%type <dbl> float_or_perc

%error-verbose

%%

test
 : bpm { add_new_BP ($1); }
 | bpx { add_new_BP ($1); }
 | bpf { add_new_BP (create_BP(BP_type_BPF, current_BPF)); current_BPF=NULL; }
 | LOAD_FILENAME { load_filename=$1; };
 ;

bpm
 : BPM_width address COMMA W        
   { $$=create_BP(BP_type_BPM, create_BPM ($2, $1, BPM_type_W)); }
 | BPM_width address COMMA RW       
   { $$=create_BP(BP_type_BPM, create_BPM ($2, $1, BPM_type_RW)); }
 ;

bpx
 : BPX_EQ address
   { $$=create_BP(BP_type_BPX, create_BPX ($2, NULL)); }
 | BPX_EQ address COMMA BPX_options
   { $$=create_BP(BP_type_BPX, create_BPX ($2, $4)); }
 ;

bpf
 : BPF_EQ address                   { current_BPF->a=$2; } 
 | BPF_EQ address COMMA BPF_options { current_BPF->a=$2; }
 ;

BPX_options
 : BPX_option COMMA BPX_options
 { $$=cons (create_obj_opaque ($1, (void(*)(void*))dump_BPX_option, (void(*)(void*))BPX_option_free), $3); }
 | BPX_option
 { $$=cons (create_obj_opaque ($1, (void(*)(void*))dump_BPX_option, (void(*)(void*))BPX_option_free), NULL); }
 ;

BPF_options
 : BPF_option COMMA BPF_options
 | BPF_option
 ;

BPX_option
 : DUMP_OP address COMMA DEC_OR_HEX CP
 { $$=DCALLOC(BPX_option, 1, "BPX_option"); $$->t=BPX_option_DUMP; $$->a=$2; $$->size_or_value=$4; }
 | DUMP_OP address CP
 { $$=DCALLOC(BPX_option, 1, "BPX_option"); $$->t=BPX_option_DUMP; $$->a=$2; $$->size_or_value=BPX_DUMP_DEFAULT; }
 | DUMP_OP REGISTER COMMA DEC_OR_HEX CP
 { $$=DCALLOC(BPX_option, 1, "BPX_option"); $$->t=BPX_option_DUMP; $$->reg=$2; $$->size_or_value=$4; }
 | DUMP_OP REGISTER CP
 { $$=DCALLOC(BPX_option, 1, "BPX_option"); $$->t=BPX_option_DUMP; $$->reg=$2; $$->size_or_value=BPX_DUMP_DEFAULT; }
 | SET_OP REGISTER COMMA DEC_OR_HEX CP
 { $$=DCALLOC(BPX_option, 1, "BPX_option"); $$->t=BPX_option_SET; $$->reg=$2; $$->size_or_value=$4; }
 | COPY_OP address COMMA QUOTE cstring QUOTE CP
 { $$=DCALLOC(BPX_option, 1, "BPX_option"); $$->t=BPX_option_COPY; $$->a=$2; $$->copy_string=$5; }
 | COPY_OP REGISTER COMMA QUOTE cstring QUOTE CP
 { $$=DCALLOC(BPX_option, 1, "BPX_option"); $$->t=BPX_option_COPY; $$->reg=$2; $$->copy_string=$5; }
 ;

BPF_option
 : BPF_UNICODE                      { current_BPF->unicode=1; }
 | BPF_TRACE                        { current_BPF->trace=1; }
 | BPF_TRACE_COLON BPF_CC           { current_BPF->trace=1; current_BPF->trace_cc=1; }
 | BPF_SKIP                         { current_BPF->skip=1; } 
 | BPF_SKIP_STDCALL                 { current_BPF->skip_stdcall=1; }
 | BPF_PAUSE DEC_OR_HEX             { current_BPF->pause=$2; }
 | BPF_RT DEC_OR_HEX                { current_BPF->rt=obj_int($2); }
 | BPF_RT_PROBABILITY float_or_perc { current_BPF->rt_probability=$2; }
 | BPF_ARGS DEC_OR_HEX              { current_BPF->args=$2; }
 | BPF_DUMP_ARGS DEC_OR_HEX         { current_BPF->dump_args=$2; }
 | WHEN_CALLED_FROM_ADDRESS address { current_BPF->when_called_from_address=$2; }
 | WHEN_CALLED_FROM_FUNC address    { current_BPF->when_called_from_func=$2; }
 ;

float_or_perc
 : FLOAT_NUMBER
 | DEC_NUMBER PERCENT { $$=(double)$1/(double)100; }
 ;

cstring
 : CSTRING_BYTE cstring  { $$=nconc (cons(obj_int($1), NULL), $2); }
 | CSTRING_BYTE          { $$=cons (obj_int($1), NULL); }
 ;

address
 : abs_address 
     { $$=create_address_abs ($1); }
 | FILENAME_EXCLAMATION SYMBOL_NAME_PLUS DEC_OR_HEX
     { $$=create_address_filename_symbol ($1, $2, $3); DFREE ($1); DFREE ($2); }
 | FILENAME_EXCLAMATION SYMBOL_NAME
     { $$=create_address_filename_symbol ($1, $2, 0); DFREE ($1); DFREE ($2); }
 | FILENAME_EXCLAMATION HEX_NUMBER
     { $$=create_address_filename_address ($1, $2); DFREE ($1); }
 | BYTEMASK bytemask BYTEMASK_END 
     { $$=create_address_bytemask ($2); }
 ;

DEC_OR_HEX
 : DEC_NUMBER
 | HEX_NUMBER
 ;

abs_address
 : HEX_NUMBER
 ;

bytemask
 : bytemask_element bytemask { $$=nconc ($1, $2); }
 | bytemask_element
 ;

bytemask_element
 : HEX_BYTE     { $$=cons (obj_int($1), NULL); }
 | TWO_POINTS   { $$=cons (obj_int(BYTEMASK_WILDCARD_BYTE), NULL); }
 | skip_n       { $$=obj_int_n_times (BYTEMASK_WILDCARD_BYTE, $1); }
 ;

skip_n
 : SKIP DEC_NUMBER R_SQUARE_BRACKET { $$=$2; }
 ;

%%

BP* parse_option(char *s)
{
    int r;
    flex_restart();
    flex_set_str(s);
    r=yyparse();
    flex_cleanup();
    if (r==0)
    {
        obj *tmp=car(breakpoints);
        assert (breakpoints);
        assert (tmp);
        return obj_unpack_opaque(tmp);
    }
    else
        return NULL;
};

void do_test(char *s)
{
    BP *b;
    printf ("do_test(%s)\n", s);
    
    b=parse_option(s);
    if (b)
    {
        dump_BP(b);
        printf ("\n");     
        //BP_free(b);
        obj_free (breakpoints);
        breakpoints=NULL;
    }
    else
    {
        exit(0);
    };
};

void main()
{
    //yydebug=1;
    do_test("bpmq=file.dll!symbol,rw\0");
    do_test("bpmq=file.dll!symbol+0x123,w\0");
    do_test("bpmb=0x123123,w\0");
    do_test("bpmq=file.dll!symbol+123,rw\0");
    do_test("bpmd=0x12345678,w\0");
    do_test("bpmw=bytemask:\"001122\",w\0");
    do_test("bpmd=bytemask:\"0011..22\",rw\0");
    do_test("bpmq=bytemask:\"0011[skip:2]22\",w\0");
    do_test("bpmb=bytemask:\"001122..3355[skip:2]1166..77\",rw\0");
    do_test("bpx=0x123123\0");
    do_test("bpx=0x123123,dump(eax,1234)\0");
    do_test("bpx=0x123123,dump(filename.dll!symbol,0x29a)\0");
    do_test("bpx=filename.dll!symbol1,dump(filename.dll!symbol2,0x29a)\0");
    do_test("bpx=filename.dll!symbol1,dump(filename.dll!symbol3),dump(eax,123)\0");
    do_test("bpx=filename.dll!symbol1,copy(eax,\"hahaha\\x00\\x11hoho\")\0");
    do_test("bpx=bytemask:\"001122..3355[skip:2]1166..77\",copy(eax,\"hahaha\\x00\\x11hoho\")\0");
    do_test("bpx=filename.dll!symbol1,copy(filename.dll!symbol2,\"hahaha\\x00\\x11hoho\")\0");
    do_test("bpx=filename.dll!symbol1,set(eax,111),set(ebx,222),dump(filename.dll!symbol3,333)\0");
    do_test("bpf=filename.dll!symbol1,args:6,skip,unicode,when_called_from_func:filename.dll!func,rt:123\0");
    do_test("bpf=filename.dll!symbol1,dump_args:6,skip_stdcall,when_called_from_address:filename.dll!func+0x1234,rt_probability:0.17,pause:700\0");
    do_test("bpf=filename.dll!symbol1,rt_probability:50%,rt:123\0");
    do_test("bpf=filename.dll!symbol1,rt_probability:0%,rt:123\0");
    do_test("bpf=filename.dll!symbol1,rt_probability:1%,rt:123\0");
    do_test("bpf=filename.dll!symbol1,rt_probability:100%,rt:123\0");
    do_test("bpx=filename.dll!0x12345678,dump(eax,123)\0");
    dump_unfreed_blocks();
}

yyerror(char *s)
{
  fprintf(stderr, "bison error: %s\n", s);
}