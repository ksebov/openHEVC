#ifndef OPEN_HEVC_WRAPPER_H
#define OPEN_HEVC_WRAPPER_H

#define NV_VERSION  "1.2" ///< Current software version

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

typedef void* OpenHevc_Handle;

typedef struct OpenHevc_Rational{
    int num; ///< numerator
    int den; ///< denominator
} OpenHevc_Rational;

typedef struct OpenHevc_FrameInfo
{
   int         nYPitch;
   int         nUPitch;
   int         nVPitch;
   int         nBitDepth;
   int         nWidth;
   int         nHeight;
   OpenHevc_Rational  sample_aspect_ratio;
   OpenHevc_Rational  frameRate;
   int         display_picture_number;
   int         flag; //progressive, interlaced, interlaced top field first, interlaced bottom field first.
   int64_t     nTimeStamp;
} OpenHevc_FrameInfo;

typedef struct OpenHevc_Frame
{
   void**      pvY;
   void**      pvU;
   void**      pvV;
   OpenHevc_FrameInfo frameInfo;
} OpenHevc_Frame;

typedef struct OpenHevc_Frame_cpy
{
   void*        pvY;
   void*        pvU;
   void*        pvV;
   OpenHevc_FrameInfo frameInfo;
} OpenHevc_Frame_cpy;

OpenHevc_Handle libOpenHevcInit(int nb_pthreads, int nb_layers, int enable_frame_based);
int  libOpenHevcDecode(OpenHevc_Handle openHevcHandle, const unsigned char *buff, int nal_len, int64_t pts, int nb_layers);
void libOpenHevcGetPictureInfo(OpenHevc_Handle openHevcHandle, OpenHevc_FrameInfo *openHevcFrameInfo);
void libOpenHevcGetPictureSize2(OpenHevc_Handle openHevcHandle, OpenHevc_FrameInfo *openHevcFrameInfo);
int  libOpenHevcGetOutput(OpenHevc_Handle openHevcHandle, int got_picture, OpenHevc_Frame *openHevcFrame);
int  libOpenHevcGetOutputCpy(OpenHevc_Handle openHevcHandle, int got_picture, OpenHevc_Frame_cpy *openHevcFrame);

void libOpenHevcSetCheckMD5(OpenHevc_Handle openHevcHandle, int val);
void libOpenHevcSetLayerId(OpenHevc_Handle openHevcHandle, int val);
void libOpenHevcSetDisableAU(OpenHevc_Handle openHevcHandle, int val);
void libOpenHevcClose(OpenHevc_Handle openHevcHandle);
void libOpenHevcSetTemporalLayer_id(OpenHevc_Handle openHevcHandle, int val);

void libOpenHevcFlush(OpenHevc_Handle openHevcHandle);
const char *libOpenHevcVersion(OpenHevc_Handle openHevcHandle);

#ifdef __cplusplus
}
#endif

#endif // OPEN_HEVC_WRAPPER_H
