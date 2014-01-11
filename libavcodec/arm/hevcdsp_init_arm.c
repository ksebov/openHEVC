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


static av_cold void hevcdsp_init_neon(HEVCDSPContext *c, const int bit_depth)
{
#if  HAVE_NEON
    if (bit_depth == 8) {
//    c->hevc_h_loop_filter_luma      = 0;
//    c->hevc_v_loop_filter_luma      = 0;
    }
#endif // HAVE_NEON
}

av_cold void ff_hevcdsp_init_arm(HEVCDSPContext *c, const int bit_depth)
{
    int cpu_flags = av_get_cpu_flags();

    if (have_neon(cpu_flags))
        hevcdsp_init_neon(c, bit_depth);
}
