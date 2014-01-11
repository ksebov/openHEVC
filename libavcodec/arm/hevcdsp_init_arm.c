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

#include <stdint.h>

#include "libavutil/attributes.h"
#include "libavutil/arm/cpu.h"
#include "libavcodec/hevcdsp.h"

void _hevc_v_deblock_luma_8_neon( const uint8_t* ptr, uint32_t stride, int32_t beta_tc_flags );
void _hevc_h_deblock_luma_8_neon( const uint8_t* ptr, uint32_t stride, int32_t beta_tc_flags );

static inline int32_t beta_tc_flags( const int *_beta, const int *_tc, const uint8_t *_no_p, const uint8_t *_no_q)
{
    return (*_beta << 13) | (*_tc << 4) | (*_no_q << 1) | (*_no_p << 0); // Note: Assembly code in hevc_deblock_neon.S depends on this packing.
}

void hevc_h_deblock_luma_8_neon(uint8_t *_pix, ptrdiff_t _stride, int *_beta, int *_tc, uint8_t *_no_p, uint8_t *_no_q)
{
    _hevc_h_deblock_luma_8_neon( _pix, _stride, beta_tc_flags( _beta, _tc, _no_p, _no_q ));
    ++_beta; ++_tc; ++_no_p; ++_no_q; _pix += 4;

    _hevc_h_deblock_luma_8_neon( _pix, _stride, beta_tc_flags( _beta, _tc, _no_p, _no_q ));
}

void hevc_v_deblock_luma_8_neon(uint8_t *_pix, ptrdiff_t _stride, int *_beta, int *_tc, uint8_t *_no_p, uint8_t *_no_q)
{
    _hevc_v_deblock_luma_8_neon( _pix, _stride, beta_tc_flags( _beta, _tc, _no_p, _no_q ));
    ++_beta; ++_tc; ++_no_p; ++_no_q; _pix += 4*_stride;

    _hevc_v_deblock_luma_8_neon( _pix, _stride, beta_tc_flags( _beta, _tc, _no_p, _no_q ));
}


static av_cold void hevcdsp_init_neon(HEVCDSPContext *c, const int bit_depth)
{
#if  HAVE_NEON
    if (bit_depth == 8) {
    c->hevc_h_loop_filter_luma_c    =
    c->hevc_h_loop_filter_luma      = hevc_h_deblock_luma_8_neon;
    c->hevc_v_loop_filter_luma_c    =
    c->hevc_v_loop_filter_luma      = hevc_v_deblock_luma_8_neon;
    }
#endif // HAVE_NEON
}

av_cold void ff_hevcdsp_init_arm(HEVCDSPContext *c, const int bit_depth)
{
    int cpu_flags = av_get_cpu_flags();

    if (have_neon(cpu_flags))
        hevcdsp_init_neon(c, bit_depth);
}
