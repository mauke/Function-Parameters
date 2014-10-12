/* vi: set ft=c inde=: */

#ifndef pad_block_start

#define pad_block_start(A) S_pad_block_start(aTHX_ A)

static void S_pad_block_start(pTHX_ int full) {
    dVAR;
    ASSERT_CURPAD_ACTIVE("pad_block_start");
    SAVEI32(PL_comppad_name_floor);
    PL_comppad_name_floor = AvFILLp(PL_comppad_name);
    if (full)
        PL_comppad_name_fill = PL_comppad_name_floor;
    if (PL_comppad_name_floor < 0)
        PL_comppad_name_floor = 0;
    SAVEI32(PL_min_intro_pending);
    SAVEI32(PL_max_intro_pending);
    PL_min_intro_pending = 0;
    SAVEI32(PL_comppad_name_fill);
    SAVEI32(PL_padix_floor);
    PL_padix_floor = PL_padix;
    PL_pad_reset_pending = FALSE;
}

#endif
