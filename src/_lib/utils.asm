#importonce

.function _16bitnextArgument(arg) {
    .if (arg.getType()==AT_IMMEDIATE)
    .return CmdArgument(arg.getType(),>arg.getValue())
    .return CmdArgument(arg.getType(),arg.getValue()+1)
}

.pseudocommand mov16 src:tar {
 lda src
 sta tar
 lda _16bitnextArgument(src)
 sta _16bitnextArgument(tar)
}

.pseudocommand mov src:tar {
 lda src
 sta tar
}