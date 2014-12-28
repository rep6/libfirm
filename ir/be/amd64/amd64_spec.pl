$arch = "amd64";

$mode_gp      = "mode_Lu";
$mode_flags   = "mode_Iu";
$mode_xmm     = "amd64_mode_xmm";
$status_flags = "all"; # TODO
$all_flags    = "all";

%reg_classes = (
	gp => [
		{ name => "rax", dwarf => 0 },
		{ name => "rcx", dwarf => 2 },
		{ name => "rdx", dwarf => 1 },
		{ name => "rsi", dwarf => 4 },
		{ name => "rdi", dwarf => 5 },
		{ name => "rbx", dwarf => 3 },
		{ name => "rbp", dwarf => 6 },
		{ name => "rsp", dwarf => 7 },
		{ name => "r8",  dwarf => 8 },
		{ name => "r9",  dwarf => 9 },
		{ name => "r10", dwarf => 10 },
		{ name => "r11", dwarf => 11 },
		{ name => "r12", dwarf => 12 },
		{ name => "r13", dwarf => 13 },
		{ name => "r14", dwarf => 14 },
		{ name => "r15", dwarf => 15 },
		{ mode => $mode_gp }
	],
	flags => [
		{ name => "eflags", dwarf => 49 },
		{ mode => $mode_flags, flags => "manual_ra" }
	],
	xmm => [
		{ name => "xmm0", dwarf => 17 },
		{ name => "xmm1", dwarf => 18 },
		{ name => "xmm2", dwarf => 19 },
		{ name => "xmm3", dwarf => 20 },
		{ name => "xmm4", dwarf => 21 },
		{ name => "xmm5", dwarf => 22 },
		{ name => "xmm6", dwarf => 23 },
		{ name => "xmm7", dwarf => 24 },
		{ mode => $mode_xmm }
	]
);

sub amd64_custom_init_attr {
	my $constr = shift;
	my $node   = shift;
	my $name   = shift;
	my $res    = "";

	if(defined($node->{modified_flags})) {
		$res .= "\tarch_add_irn_flags(res, arch_irn_flag_modify_flags);\n";
	}
	return $res;
}
$custom_init_attr_func = \&amd64_custom_init_attr;

%custom_irn_flags = (
	commutative => "(arch_irn_flags_t)amd64_arch_irn_flag_commutative_binop",
);

$default_copy_attr = "amd64_copy_attr";

%init_attr = (
	amd64_attr_t =>
		"init_amd64_attributes(res, irn_flags_, in_reqs, n_res, op_mode);",
	amd64_addr_attr_t =>
		"init_amd64_attributes(res, irn_flags_, in_reqs, n_res, op_mode);\n"
		."\tattr->insn_mode = insn_mode;\n"
		."\tattr->addr = addr;",
	amd64_asm_attr_t =>
		"init_amd64_attributes(res, irn_flags_, in_reqs, n_res, op_mode);\n"
		."\tattr->asmattr = *asmattr;\n",
	amd64_binop_addr_attr_t =>
		"be_info_init_irn(res, irn_flags_, in_reqs, n_res);\n"
		."\t*attr = *attr_init;",
	amd64_switch_jmp_attr_t =>
		"init_amd64_attributes(res, irn_flags_, in_reqs, n_res, op_mode);\n"
		."\tinit_amd64_switch_attributes(res, table, table_entity);",
	amd64_cc_attr_t =>
		"init_amd64_attributes(res, irn_flags_, in_reqs, n_res, op_mode);\n"
		."\tinit_amd64_cc_attributes(res, cc);",
	amd64_movimm_attr_t =>
		"init_amd64_attributes(res, irn_flags_, in_reqs, n_res, op_mode);\n"
		."\tinit_amd64_movimm_attributes(res, insn_mode, entity, offset);",
	amd64_shift_attr_t =>
		"be_info_init_irn(res, irn_flags_, in_reqs, n_res);\n"
		."\t*attr = *attr_init;\n",
);

%nodes = (
push_am => {
	op_flags  => [ "uses_memory" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "rsp:I|S", "none" ] },
	arity     => "variable",
	outs      => [ "stack", "M" ],
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_addr_t addr",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_ADDR;\n",
	emit      => "push%M %A",
},

push_rbp => {
	op_flags  => [ "uses_memory" ],
	state     => "exc_pinned",
	reg_req   => { in => [ "rsp" ], out => [ "rsp:I|S" ] },
	ins       => [ "stack" ],
	outs      => [ "stack" ],
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_NONE;\n",
	emit      => "pushq %%rbp",
},

pop_am => {
	op_flags  => [ "uses_memory" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "rsp:I|S", "none" ] },
	arity     => "variable",
	outs      => [ "stack", "M" ],
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_addr_t addr",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_ADDR;\n",
	emit      => "pop%M %A",
},

sub_sp => {
	state     => "pinned",
	reg_req   => { out => [ "rsp:I|S", "gp", "none" ] },
	outs      => [ "stack", "addr", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "subq %AM\n".
	             "movq %%rsp, %D1",
	modified_flags => $status_flags,
},

leave => {
	op_flags  => [ "uses_memory" ],
	state     => "exc_pinned",
	reg_req   => { in => [ "rbp" ], out => [ "rbp:I", "rbp:I|S" ] },
	outs      => [ "frame", "stack" ],
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_NONE;\n",
	emit      => "leave",
},

add => {
	irn_flags => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "flags", "none" ] },
	arity     => "variable",
	outs      => [ "res", "flags", "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "add%M %AM",
	modified_flags => $status_flags,
},

and => {
	irn_flags => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "flags", "none" ] },
	arity     => "variable",
	outs      => [ "res", "flags", "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "and%M %AM",
	modified_flags => $status_flags,
},

asm => {
	arity     => "variable",
	out_arity => "variable",
	attr_type => "amd64_asm_attr_t",
	attr      => "const x86_asm_attr_t *asmattr",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_NONE;\n",
},

div => {
	state     => "pinned",
	reg_req   => { out => [ "rax", "flags", "none", "rdx" ] },
	arity     => "variable",
	outs      => [ "res_div", "flags", "M", "res_mod" ],
	attr_type => "amd64_addr_attr_t",
	fixed     => "amd64_addr_t addr = { { NULL, 0 }, NO_INPUT, NO_INPUT, NO_INPUT, 0, AMD64_SEGMENT_DEFAULT };\n"
	            ."amd64_op_mode_t op_mode = AMD64_OP_RAX_REG;\n",
	attr      => "amd64_insn_mode_t insn_mode",
	emit      => "div%M %AM",
	modified_flags => $status_flags,
},

idiv => {
	state     => "pinned",
	reg_req   => { out => [ "rax", "flags", "none", "rdx" ] },
	arity     => "variable",
	outs      => [ "res_div", "flags", "M", "res_mod" ],
	attr_type => "amd64_addr_attr_t",
	fixed     => "amd64_addr_t addr = { { NULL, 0 }, NO_INPUT, NO_INPUT, NO_INPUT, 0, AMD64_SEGMENT_DEFAULT };\n"
	            ."amd64_op_mode_t op_mode = AMD64_OP_RAX_REG;\n",
	attr      => "amd64_insn_mode_t insn_mode",
	emit      => "idiv%M %AM",
	modified_flags => $status_flags,
},

imul => {
	irn_flags => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "flags", "none" ] },
	outs      => [ "res", "flags", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "imul%M %AM",
	modified_flags => $status_flags,
},

imul_1op => {
	# Do not rematerialize this node
	# TODO: should mark this commutative as soon as the backend code
	#       can handle this special case
	# It produces 2 results and has strict constraints
	state     => "exc_pinned",
	reg_req   => { out => [ "rax", "flags", "none", "rdx" ] },
	outs      => [ "res_low", "flags", "M", "res_high" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "imul%M %AM",
	modified_flags => $status_flags,
},

mul => {
	# Do not rematerialize this node
	# It produces 2 results and has strict constraints
	state     => "exc_pinned",
	reg_req   => { out => [ "rax", "flags", "none", "rdx" ] },
	outs      => [ "res_low", "flags", "M", "res_high" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "mul%M %AM",
	modified_flags => $status_flags,
},

or => {
	irn_flags => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "flags", "none" ] },
	outs      => [ "res", "flags", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "or%M %AM",
	modified_flags => $status_flags,
},

shl => {
	irn_flags => [ "rematerializable" ],
	reg_req   => { out => [ "gp", "flags" ] },
	outs      => [ "res", "flags" ],
	arity     => "variable",
	attr_type => "amd64_shift_attr_t",
	attr      => "const amd64_shift_attr_t *attr_init",
	emit      => "shl%MS %SO",
	modified_flags => $status_flags
},

shr => {
	irn_flags => [ "rematerializable" ],
	reg_req   => { out => [ "gp", "flags" ] },
	outs      => [ "res", "flags" ],
	arity     => "variable",
	attr_type => "amd64_shift_attr_t",
	attr      => "const amd64_shift_attr_t *attr_init",
	emit      => "shr%MS %SO",
	modified_flags => $status_flags
},

sar => {
	irn_flags => [ "rematerializable" ],
	reg_req   => { out => [ "gp", "flags" ] },
	outs      => [ "res", "flags" ],
	arity     => "variable",
	attr_type => "amd64_shift_attr_t",
	attr      => "const amd64_shift_attr_t *attr_init",
	emit      => "sar%MS %SO",
	modified_flags => $status_flags
},

sub => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "flags", "none" ] },
	outs      => [ "res", "flags", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "sub%M %AM",
	modified_flags => $status_flags,
},

sbb => {
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "flags", "none" ] },
	outs      => [ "res", "flags", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "sbb%M %AM",
	modified_flags => $status_flags,
},

neg => {
	irn_flags => [ "rematerializable" ],
	reg_req   => { in => [ "gp" ], out => [ "in_r1", "flags" ] },
	ins       => [ "val" ],
	outs      => [ "res", "flags" ],
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_UNOP_REG;\n"
	            ."amd64_addr_t addr = { { NULL, 0 }, NO_INPUT, NO_INPUT, NO_INPUT, 0, AMD64_SEGMENT_DEFAULT };",
	emit      => "neg%M %AM",
	modified_flags => $status_flags
},

not => {
	irn_flags => [ "rematerializable" ],
	attr      => "amd64_insn_mode_t insn_mode",
	init_attr => "attr->insn_mode = insn_mode;",
	reg_req   => { in => [ "gp" ], out => [ "in_r1", "flags" ] },
	ins       => [ "val" ],
	outs      => [ "res", "flags" ],
	attr_type => "amd64_addr_attr_t",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_UNOP_REG;\n"
	            ."amd64_addr_t addr = { { NULL, 0 }, NO_INPUT, NO_INPUT, NO_INPUT, 0, AMD64_SEGMENT_DEFAULT };",
	emit      => "not%M %AM",
	modified_flags => $status_flags
},

xor => {
	irn_flags => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "flags", "none" ] },
	arity     => "variable",
	outs      => [ "res", "flags", "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "xor%M %AM",
	modified_flags => $status_flags,
},

xor_0 => {
	op_flags  => [ "constlike" ],
	irn_flags => [ "rematerializable" ],
	reg_req   => { out => [ "gp", "flags" ] },
	outs      => [ "res", "flags" ],
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_REG_REG;",
	emit      => "xorl %3D0, %3D0",
	modified_flags => $status_flags,
},

mov_imm => {
	op_flags  => [ "constlike" ],
	irn_flags => [ "rematerializable" ],
	reg_req   => { out => [ "gp" ] },
	attr_type => "amd64_movimm_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, int64_t offset, ir_entity *entity",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_IMM64;",
	emit      => 'mov%MM $%C, %D0',
	mode      => $mode_gp,
},

movs => {
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "none", "none" ] },
	outs      => [ "res", "unused", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "movs%Mq %AM, %^D0",
},

mov_gp => {
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "none", "none" ] },
	outs      => [ "res", "unused", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
},

ijmp => {
	state     => "pinned",
	op_flags  => [ "cfopcode", "unknown_jump" ],
	reg_req   => { in => [ "gp" ], out => [ "none", "none", "none" ] },
	outs      => [ "X", "unused", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "jmp %*AM",
},

jmp => {
	state    => "pinned",
	op_flags => [ "cfopcode" ],
	reg_req  => { out => [ "none" ] },
	fixed    => "amd64_op_mode_t op_mode = AMD64_OP_IMM32;",
	mode     => "mode_X",
},

cmp => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "none", "flags", "none" ] },
	arity     => "variable",
	outs      => [ "dummy", "flags", "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "cmp%M %AM",
	modified_flags => $status_flags,
},

lea => {
	irn_flags => [ "rematerializable" ],
	arity     => "variable",
	outs      => [ "res" ],
	reg_req   => { out => [ "gp" ] },
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_addr_t addr",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_ADDR;\n",
	emit      => "lea%M %A, %D0",
	mode      => $mode_gp,
},

jcc => {
	state     => "pinned",
	op_flags  => [ "cfopcode", "forking" ],
	reg_req   => { in  => [ "eflags" ], out => [ "none", "none" ] },
	ins       => [ "eflags" ],
	outs      => [ "false", "true" ],
	attr_type => "amd64_cc_attr_t",
	attr      => "x86_condition_code_t cc",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_NONE;\n",
},

mov_store => {
	op_flags  => [ "uses_memory" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "none" ] },
	arity     => "variable",
	outs      => [ "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	mode      => "mode_M",
	emit      => "mov%M %S0, %A",
},

jmp_switch => {
	op_flags  => [ "cfopcode", "forking" ],
	state     => "pinned",
	reg_req   => { in => [ "gp" ], out => [ "none" ] },
	out_arity => "variable",
	attr_type => "amd64_switch_jmp_attr_t",
	attr      => "const ir_switch_table *table, ir_entity *table_entity",
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_NONE;\n",
},

call => {
	state     => "exc_pinned",
	arity     => "variable",
	out_arity => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_op_mode_t op_mode, amd64_addr_t addr",
	fixed     => "amd64_insn_mode_t insn_mode = INSN_MODE_64;\n",
	emit      => "call %*AM",
	modified_flags => $all_flags,
},

start => {
	irn_flags => [ "schedule_first" ],
	state     => "pinned",
	out_arity => "variable",
	ins       => [],
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_NONE;\n",
	emit      => "",
},

ret => {
	state    => "pinned",
	op_flags => [ "cfopcode" ],
	arity    => "variable",
	reg_req  => { out => [ "none" ] },
	fixed    => "amd64_op_mode_t op_mode = AMD64_OP_NONE;\n",
	mode     => "mode_X",
	emit     => "ret",
},

# SSE

adds => {
	irn_flags  => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "adds%MX %AM",
},

divs => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res_div", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "divs%MX %AM",
},

movs_xmm => {
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "unused", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "movs%MX %AM, %D0",
},

muls => {
	irn_flags => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "muls%MX %AM",
},

movs_store_xmm => {
	op_flags  => [ "uses_memory" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "none" ] },
	arity     => "variable",
	outs      => [ "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	mode      => "mode_M",
	emit      => "movs%MX %^S0, %A",
},


subs => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "subs%MX %AM",
},

ucomis => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "none", "flags", "none" ] },
	arity     => "variable",
	outs      => [ "dummy", "flags", "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "ucomis%MX %AM",
	modified_flags => $status_flags,
},

xorpd_0 => {
	op_flags  => [ "constlike" ],
	irn_flags => [ "rematerializable" ],
	reg_req   => { out => [ "xmm" ] },
	outs      => [ "res" ],
	fixed     => "amd64_op_mode_t op_mode = AMD64_OP_REG_REG;",
	emit      => "xorpd %^D0, %^D0",
	mode      => $mode_xmm,
},

xorp  => {
	irn_flags => [ "rematerializable", "commutative" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	arity     => "variable",
	outs      => [ "res", "none", "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "xorp%MX %AM",
},

# Conversion operations

cvtss2sd => {
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "cvtss2sd %AM, %^D0",
},

cvtsd2ss => {
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_op_mode_t op_mode, amd64_addr_t addr",
	fixed     => "amd64_insn_mode_t insn_mode = INSN_MODE_64;\n",
	emit      => "cvtsd2ss %AM, %^D0",
},

cvttsd2si => {
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "cvttsd2si %AM, %D0",
},

cvttss2si => {
	state     => "exc_pinned",
	reg_req   => { out => [ "gp", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "cvttss2si %AM, %D0",
},

cvtsi2ss => {
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "cvtsi2ss %AM, %^D0",
},

cvtsi2sd => {
	state     => "exc_pinned",
	reg_req   => { out => [ "xmm", "none", "none" ] },
	outs      => [ "res", "none", "M" ],
	arity     => "variable",
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_insn_mode_t insn_mode, amd64_op_mode_t op_mode, amd64_addr_t addr",
	emit      => "cvtsi2sd %AM, %^D0",
},

movq => {
	state     => "exc_pinned",
	arity     => "variable",
	outs      => [ "res", "none", "M" ],
	reg_req   => { out => [ "xmm", "none", "none" ] },
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_op_mode_t op_mode, amd64_addr_t addr",
	fixed     => "amd64_insn_mode_t insn_mode = INSN_MODE_64;\n",
	emit      => "movq %AM, %D0",
},

movdqa => {
	state     => "exc_pinned",
	arity     => "variable",
	outs      => [ "res", "none", "M" ],
	reg_req   => { out => [ "xmm", "none", "none" ] },
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_op_mode_t op_mode, amd64_addr_t addr",
	fixed     => "amd64_insn_mode_t insn_mode = INSN_MODE_128;\n",
	emit      => "movdqa %AM, %D0",
},

movdqu => {
	state     => "exc_pinned",
	arity     => "variable",
	outs      => [ "res", "none", "M" ],
	reg_req   => { out => [ "xmm", "none", "none" ] },
	attr_type => "amd64_addr_attr_t",
	attr      => "amd64_op_mode_t op_mode, amd64_addr_t addr",
	fixed     => "amd64_insn_mode_t insn_mode = INSN_MODE_128;\n",
	emit      => "movdqu %AM, %D0",
},

movdqu_store => {
	op_flags  => [ "uses_memory" ],
	state     => "exc_pinned",
	reg_req   => { out => [ "none" ] },
	arity     => "variable",
	outs      => [ "M" ],
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	mode      => "mode_M",
	emit      => "movdqu %^S0, %A",
},

l_punpckldq => {
	ins       => [ "arg0", "arg1" ],
	outs      => [ "res" ],
	attr_type => "",
	dump_func => "NULL",
	mode      => $mode_xmm,
},

l_subpd => {
	ins       => [ "arg0", "arg1" ],
	outs      => [ "res" ],
	attr_type => "",
	dump_func => "NULL",
	mode      => $mode_xmm,
},

l_haddpd => {
	ins       => [ "arg0", "arg1" ],
	outs      => [ "res" ],
	attr_type => "",
	dump_func => "NULL",
	mode      => $mode_xmm,
},

punpckldq => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	arity     => "variable",
	outs      => [ "res", "none", "M" ],
	reg_req   => { out => [ "xmm", "none", "none" ] },
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "punpckldq %AM",
},

subpd => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	arity     => "variable",
	outs      => [ "res", "none", "M" ],
	reg_req   => { out => [ "xmm", "none", "none" ] },
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "subpd %AM",
},

haddpd => {
	irn_flags => [ "rematerializable" ],
	state     => "exc_pinned",
	arity     => "variable",
	outs      => [ "res", "none", "M" ],
	reg_req   => { out => [ "xmm", "none", "none" ] },
	attr_type => "amd64_binop_addr_attr_t",
	attr      => "const amd64_binop_addr_attr_t *attr_init",
	emit      => "haddpd %AM",
},

);
