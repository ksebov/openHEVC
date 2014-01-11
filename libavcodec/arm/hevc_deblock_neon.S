/*
 * Copyright (c) 2014 Kostya Sebov <ksebov@yahoo.com>
 *
 * This file is part of FFmpeg.
 *
 * FFmpeg is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * FFmpeg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with FFmpeg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

// #include "libavutil/arm/asm.S"

.section .text

// Define global variables

ptr         .req r0
stride      .req r1
flags       .req r2

param4      .req r3
tmp         .req param4

tmp0        .req r4
tmp1        .req r5
tmp2        .req r6
tmp3        .req r7
tmp4        .req r8
tmp5        .req r9
tmp6        .req r10

.altmacro

.macro FUNCTION name
        .align  2
        .code   32
        .type   \name STT_FUNC
\name:
.endm

.macro BEGIN
        push {tmp0-tmp6,lr} // 4 cycles
.endm

.macro RETURN COND
        pop\()COND {tmp0-tmp6,pc} // 4 cycles
.endm

//
.equ flags_lsb, 0
.equ flags_wid, 2
// Padding wid  2, must be at least 1
.equ tc_lsb,    4
.equ tc_wid,    5
// Padding wid  4, must be at least 1
.equ beta_lsb,  13
.equ beta_wid,  7
// Bits left    12

vtc2        .req Q0  // vdup.u8( vct*2 )
vtc2d       .req d0  // vdup.u8( vct*2 )
src0_1      .req Q1
src0        .req d2
src1        .req d3
m0o7        .req d2 // src0
m1o6        .req d3 // src1
src2_3      .req Q2
src2        .req d4
src3        .req d5
m2o5_3o4    .req Q2 // src2_3
m2o5        .req d4 // src2
m3o4        .req d5 // src3

r1_6        .req Q3 // Strong only
coef        .req d6 // Weak only
              // d7 // Weak only
r2_5        .req Q4
r3_4        .req Q5

tmpq        .req Q5
tmpd        .req d10
tmpd2       .req d11

dst0_1      .req Q6
dst0        .req d12
dst1        .req d13
r1o6        .req d13 // dst1
dst2_3      .req Q7
dst2        .req d14
dst3        .req d15
r2o5_3o4    .req Q7  // dst2_3
r2o5        .req d14 // dst2
r3o4        .req d15 // dst3

dpq         .req Q8  // Decision only
dpq1        .req d16
dpq2        .req d17
vtc         .req Q8  // Weak only
limd        .req d16 // Strong only
              // d17
limq        .req Q9  // Strong only
vtc10       .req Q9  // Weak only

delta       .req Q10 // Weak only
delta1      .req d20 // Weak only
delta2      .req d21 // Weak only
mask        .req Q12 // Weak only
mask2_5     .req Q13 // Weak only
maskP_Q     .req Q14 // Note: Inverted mask


//  void _hevc_v_deblock_luma_8_neon( const Pel* ptr, uint32_t stride, int32_t beta_tc_flags );
.global  _hevc_v_deblock_luma_8_neon
FUNCTION _hevc_v_deblock_luma_8_neon

        BEGIN

        sub ptr,   #4
        vld1.8     {src0},     [ptr],  stride
        vld1.8     {src1},     [ptr],  stride
        vld1.8     {src2},     [ptr],  stride
        vld1.8     {src3},     [ptr],  stride

        vrev64.8   tmpq,       src0_1 // Reverse m4..m7 to m7..m4
        vtrn.32    src0_1,     tmpq   //  e.g., 01234567 -> 01237654
        vrev64.8   tmpq,       src2_3
        vtrn.32    src2_3,     tmpq

        vtrn.8     src0,       src1   // Transpose two 4x4 matrices
        vtrn.8     src2,       src3
        vtrn.16    src0_1,     src2_3

        bl         deblock_luma.doit

        cmp        ptr, #0x10000
        RETURN lt

        sub        ptr,        stride, lsl #2 // assert( ptr == &dst0 )

        vtrn.8     dst0,       dst1   // Transpose...
        vtrn.8     dst2,       dst3
        vtrn.16    dst0_1,     dst2_3

        vrev64.8   tmpq,       dst0_1 // ... and reverse back
        vtrn.32    dst0_1,     tmpq
        vrev64.8   tmpq,       dst2_3
        vtrn.32    dst2_3,     tmpq

        vst1.8     dst0,       [ptr],  stride
        vst1.8     dst1,       [ptr],  stride
        vst1.8     dst2,       [ptr],  stride
        vst1.8     dst3,       [ptr],  stride

        RETURN

//  void _hevc_h_deblock_luma_8_neon( const Pel* ptr, uint32_t stride, int32_t beta_tc_flags );
.global  _hevc_h_deblock_luma_8_neon
FUNCTION _hevc_h_deblock_luma_8_neon

        BEGIN

        sub ptr,   stride,     LSL #2 // assert( ptr == &m0 )
        vld1.32    {m0o7},     [ptr],  stride       // m0
        vld1.32    {m1o6},     [ptr],  stride       // m1
        vld1.32    {m2o5},     [ptr],  stride       // m2
        vld1.32    {m3o4},     [ptr],  stride       // m3
        vld1.32    {m3o4[1]},  [ptr],  stride       // m4
        // cycle 1
        vld1.32    {m2o5[1]},  [ptr],  stride       // m5
        // cycle 1
        vld1.32    {m1o6[1]},  [ptr],  stride       // m6
        // cycle 1
        vld1.32    {m0o7[1]},  [ptr],  stride       // m7
        // cycle 1

        bl         deblock_luma.doit

        cmp        ptr, #0x10000
        RETURN lt

        sub        ptr,        stride, lsl #3       // Use the stall // assert( ptr == &m0 )
        add        ptr,        stride               // assert( ptr == &m1 )
        vst1.32    {r1o6[0]},  [ptr],  stride
        // cycle 1
        vst1.32    {r2o5[0]},  [ptr],  stride
        // cycle 1
        vst1.32    {r3o4[0]},  [ptr],  stride
        // cycle 1
        vst1.32    {r3o4[1]},  [ptr],  stride
        // cycle 1
        vst1.32    {r2o5[1]},  [ptr],  stride
        // cycle 1
        vst1.32    {r1o6[1]},  [ptr],  stride
        // cycle 1

        RETURN

FUNCTION deblock_luma.doit
dsum   .req tmp0
dsum30 .req tmp1
d34_01 .req tmp2
d34_23 .req tmp3
dsf_01 .req tmp4
dsf_23 .req tmp5
xbeta  .req tmp6
tc5x   .req tmp
addr   .req tmp6
offset .req tmp

        vaddl.u8   dpq,        m1o6,   m3o4
        vaddl.u8   tmpq,       m2o5,   m2o5
        vabd.u16   dpq,        dpq,    tmpq         // p0 p1 p2 p3 q0 q1 q2 q3
        vzip.16    dpq1,       dpq2                 // p0 q0 p1 q1 p2 q2 p3 q3
        vext.16    dpq1,       dpq2,   dpq1, #2     // p3 q3 p0 q0 p2 q2 p3 q3
        vpadd.u16  dpq2,       dpq1,   dpq1         // p3 q3 p0 q0 d3 d0 d3 d0
        vpadd.u16  tmpd,       dpq2,   dpq2         //  d  d  d  d
        vmov.u16   dsum,       tmpd[0]              // Note: it takes 11 cycles on Cortex-A9 before dsum, etc. can be used
        vmov.u32   dsum30,     dpq2[0]              // 1
        vext.16    tmpd,       m3o4,   m3o4, #2     // 2 // m4o3
        vabdl.u8   tmpq,       m3o4,   tmpd         // 3
        vmov       d34_01,     d34_23, tmpd         // 4
        vabdl.u8   tmpq,       m0o7,   m3o4         // 5
        vadd.u16   tmpd,       tmpd,   tmpd2        // 6
        vmov       dsf_01,     dsf_23, tmpd         // 7
        ubfx tc5x, flags,      #tc_lsb, #tc_wid     // 8
        add  tc5x, tc5x,       tc5x, lsl #2 // tc*5 // 9
        lsl        tc5x,       #15                  // 10
        and        xbeta,      flags,  #(((1<<(beta_wid-2))-1))<<(beta_lsb+2) // 11 // (beta>>2)<<15, assuming assert( 15 == beta_lsb+2 )
        cmp        dsum,       flags,  lsr #beta_lsb // Now dsum can be finally used
        movge      ptr,        #0
        bxge lr // return

        cmp        xbeta,      dsum30, lsl #0       // (beta>>2)<<15 <= (d0<<16)+d3         === (beta>>2) <= 2*d0
        cmpgt      xbeta,      dsum30, lsl #16      // (beta>>2)<<15 <=  d3<<16             === (beta>>2) <= 2*d3
        cmpgt      tc5x,       d34_01, lsl #16      //    (tc*5)<<15 <=  d34_0<<16          === (tc*5)<<1 <= d34_0
        cmpgt      tc5x,       d34_23, lsl #0       //    (tc*5)<<15 <= (d34_3<<16)+0x????  === (tc*5)<<1 <= d34_3
        ble        .L.deblock.weak_filter
        bic        xbeta,      #1<<15               // (beta>>3)<<16
        cmp        xbeta,      dsf_01, lsl #16      // (beta>>3)<<16 <= (dsf_0<<16)         === (beta>>3) <= dsf_0
        cmpgt      xbeta,      dsf_23, lsl #0       // (beta>>3)<<16 <= (dsf_3<<16))x0x???? === (beta>>3) <= dsf_3
        ble        .L.deblock.weak_filter

// Strong filter
        ubfx tmp,  flags,      #tc_lsb-1, #tc_wid+1 // tc<<1, assuming assert( tc_lsb > flags_lsb+flags_wid)
        vdup.u8    vtc2,       tmp
        vaddl.u8   r2_5,       m1o6,   m2o5         // ( m1 + m2          ,         + m5 + m6 )
        vaddw.u8   r2_5,       r2_5,   m3o4         // ( m1 + m2 + m3     ,      m4 + m5 + m6 )
        vext.32    tmpd,       m3o4,   m3o4, #1     // (                m4, m3                )
        vaddw.u8   r2_5,       r2_5,   tmpd         // ( m1 + m2 + m3 + m4, m3 + m4 + m5 + m6 )

        vaddl.u8   r1_6,       m0o7,   m1o6         // ( res1, res6 ) = ( m0 + m1, m7 + m6 )...
        vext.32    tmpd,       m2o5,   m2o5, #1     // m5o2
        vadd.u16   r1_6,       r1_6,   r1_6         // ( res1, res6 ) = ( 2*( m0 + m1 ), 2*( m6 + m7 )) ... Note: vadd is less pipeline hog than vshl #1
        vsubl.u8   r3_4,       tmpd,   m1o6         // ( res3, res4 ) = ( m5 - m1, m2 - m6 )...
        vadd.u16   r1_6,       r1_6,   r2_5         // res1 = 2*( m0 + m1 ) + ( m1 + m2 + m3 + m4 ) == 2*m0 + 3*m1 + m2 + m3 + m4
                                                    // res6 = 2*( m6 + m7 ) + ( m3 + m4 + m5 + m6 ) == m3 + m4 + m5 + 3*m6 + 2*m7
        vadd.u16   r2_5,       r2_5,   r2_5         // ( res2, res5 ) = 2*( m1 + m2 + m3 + m4 ), 2*( m3 + m4 + m5 + m6 ))
        vadd.s16   r3_4,       r3_4,   r2_5         // res3 = ( m5 - m1 ) + 2*( m1 + m2 + m3 + m4 ) == m1 + 2*m2 + 2*m3 + 2*m4 + m5
                                                    // res4 = ( m2 - m6 ) + 2*( m3 + m4 + m5 + m6 ) == m2 + 2*m3 + 2*m4 + 2*m5 + m6
        vqrshrn.u16 r1o6,      r1_6,     #3
        vqrshrn.u16 r2o5,      r2_5,     #3
        vqadd.u8    limd,      m1o6,     vtc2d
        vqrshrn.u16 r3o4,      r3_4,     #3
        vmin.u8     r1o6,      limd,     r1o6       // Note: limd is ready 1 tick later and vmin requires its 1st arg later than 2nd, so the order is important
        vqsub.u8    limd,      m1o6,     vtc2d
        vqadd.u8    limq,      m2o5_3o4, vtc2
        vmax.u8     r1o6,      limd,     r1o6       // Note: limd is ready 1 tick later and vmax requires its 1st arg later than 2nd, so the order is important
        vmin.u8     r2o5_3o4,  limq,     r2o5_3o4   // Note: limq is ready 1 tick later and vmin requires its 1st arg later than 2nd, so the order is important
        vqsub.u8    limq,      m2o5_3o4, vtc2
        lsls        flags,     #30                  // Use stall while vmas waits for r2o5_3o4 from vmin
        vmax.u8     r2o5_3o4,  limq,     r2o5_3o4   // Note: limq is ready 1 tick later and vmax requires its 1st arg later than 2nd, so the order is important
        vmov        dst0,      m0o7                 // May be reused for stalls
        bxeq        lr
        blt         .L.deblock.P_only
        vmov.u64    limd,      #0x00000000FFFFFFFF
        b           .L.deblock.restore_m
.L.deblock.P_only:
        vmov.u64    limd,      #0xFFFFFFFF00000000
.L.deblock.restore_m:
        vbit        r1o6,      m1o6,   limd
        vbit        r2o5,      m2o5,   limd
        vbit        r3o4,      m3o4,   limd
        bx          lr

.L.deblock.weak_filter:
        vrev64.32  dpq2, dpq1                       // p3 q3 p0 q0 p0 q0 p3 q3
        vzip.16    dpq1, dpq2                       // p3 p0 q3 q0 p0 p3 q0 q3
        vaddl.u16  dpq,        dpq1,   dpq2         // dp dp dq dq
        add        tmp, flags, flags,  lsr #1       // assert( flags[beta_lsb-1] == 0 );
        ubfx       tmp, tmp,   #beta_lsb+3, #beta_wid-3
        vdup.u32   tmpq,       tmp                  // (beta+(beta>>1))>>3
        vclt.u32   mask2_5,    dpq, tmpq

        and        offset,     flags,  #3
        adr        addr,       maskP_Q_patterns
        add        addr,       offset, lsl #4
        vld1.8     {maskP_Q},  [addr:64]

        vmov.u8    coef,       #9
        vmull.u8   delta,      m3o4,   coef         // ( 9*m3, 9*m4 )
        ubfx tmp2, flags,      #tc_lsb, #tc_wid
        vdup.s16   vtc,        tmp2
        vmov.u8    coef,       #3
        vmlsl.u8   delta,      m2o5,   coef         // ( 9*m3 - 3*m2, 9*m4 - 3*m5 )
        vmov.s16   coef,       #10
        vmul.s16   vtc10,      vtc,    coef[0]
        // cycle 1
        vrhadd.u8  r2o5,       m1o6,   m3o4
        vsub.s16   delta1,     delta2, delta1       // 9*m4 - 3*m5 - 9*m3 + 3*m2 = 9*(m4-m3) - 3*(m5-m2)
        vsubl.u8   r2_5,       r2o5,   m2o5
        vrshr.s16  delta1,     delta1, #4
        vshr.s16   vtc2,       vtc,    #1
        vmov       dst0_1,     src0_1               // Use the stall
        vneg.s16   delta2,     delta1
        vabs.s16   tmpq,       delta
        vmin.s16   delta,      delta,  vtc
        vneg.s16   vtc,        vtc
        vclt.s16   mask,       tmpq,   vtc10
        vmax.s16   delta,      delta,  vtc
        vbic       mask,       mask,   maskP_Q
        vhadd.s16  r2_5,       r2_5,   delta
        vand       delta,      delta,  mask
        vaddw.u8   r3_4,       delta,  m3o4
        vmin.s16   r2_5,       r2_5,   vtc2
        vneg.s16   vtc2,       vtc2
        vqmovun.s16 r3o4,      r3_4
        vmax.s16   r2_5,       r2_5,   vtc2
        vand       mask,       mask2_5
        vand       r2_5,       r2_5,   mask
        vaddw.u8   r2_5,       r2_5,   m2o5
        vqmovun.s16 r2o5,      r2_5                 // 2 more cycles until r2o5 is available for vst
        bx         lr                               // return

.unreq  tmp
.unreq  tmp2

.align 3
maskP_Q_patterns:
        .fill 16, 1, 0

        .fill 8, 1, 0xff
        .fill 8, 1, 0

        .fill 8, 1, 0
        .fill 8, 1, 0xff

        .fill 16, 1, 0xff

// Undefine global variables

.unreq  ptr
.unreq  stride
.unreq  flags

.unreq vtc2
.unreq vtc2d
.unreq src0_1
.unreq src0
.unreq src1
.unreq m0o7
.unreq m1o6
.unreq src2_3
.unreq src2
.unreq src3
.unreq m2o5_3o4
.unreq m2o5
.unreq m3o4
.unreq r2_5
.unreq r1_6
.unreq r3_4
.unreq tmpq
.unreq tmpd
.unreq tmpd2
.unreq dst0_1
.unreq dst0
.unreq dst1
.unreq r1o6
.unreq dst2_3
.unreq dst2
.unreq dst3
.unreq r2o5_3o4
.unreq r2o5
.unreq r3o4
.unreq limd
.unreq limq

.end
