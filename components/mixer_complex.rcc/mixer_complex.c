#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/*
 * THIS FILE WAS ORIGINALLY GENERATED ON Tue May 22 09:05:20 2012 EDT
 * BASED ON THE FILE: mixer_complex.xml
 * YOU ARE EXPECTED TO EDIT IT
 *
 * This file contains the RCC implementation skeleton for worker: mixer_complex
 */
#include "mixer_complex_Worker.h"



static uint32_t runConditionMasks[] = { (1<<MIXER_COMPLEX_IN_IF) | (1<<MIXER_COMPLEX_OUT), 0 };
static RCCRunCondition rc = { runConditionMasks, 0 , 0 };


MIXER_COMPLEX_METHOD_DECLARATIONS;
RCCDispatch mixer_complex = {
 /* insert any custom initializations here */
  .runCondition = &rc,
 MIXER_COMPLEX_DISPATCH
};

/*
 * Methods to implement for worker mixer_complex, based on metadata.
 */

static RCCResult
run(RCCWorker *self, RCCBoolean timedOut, RCCBoolean *newRunCondition) {
  (void)timedOut;(void)newRunCondition;


 RCCPort
   *in = &self->ports[MIXER_COMPLEX_IN_IF],
   *out = &self->ports[MIXER_COMPLEX_OUT];
   

 uint16_t
   *inData = in->current.data,
   *outData = out->current.data;

 switch( in->input.u.operation ) {


 case MIXER_COMPLEX_IN_IF_MESSAGE:

   {
     if (in->input.length > out->current.maxLength) {
       self->errorString = "output buffer too small";
       return RCC_ERROR;
     }
     printf("In mixer_complex  got data = %s, len = %d\n", inData, in->input.length );
     memcpy( outData, inData, in->input.length);
     out->output.length = in->input.length;
     out->output.u.operation = in->input.u.operation;
   }
   break;


 case MIXER_COMPLEX_IN_IF_IQ:
   //   processSignalData( self  );

 case MIXER_COMPLEX_IN_IF_SYNC:
   //   processSyncSignal( self  );

 case MIXER_COMPLEX_IN_IF_TIME:
   //   processTimeSignal( self );
   memcpy( outData, inData, in->input.length);
   out->output.length = in->input.length;
   out->output.u.operation = in->input.u.operation;
   break;
   
 };

 return RCC_ADVANCE;
}