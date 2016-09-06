//
//  CMPipe.m
//  Filter (CoreModem)
//
//  Created by Kok Chen on 10/24/05.
	#include "Copyright.h"
//

#import "CMPipe.h"


@implementation CMPipe

@synthesize outputClient = _outputClient;
@synthesize staticStream = _staticStream;
@synthesize data         = _data;
@synthesize isPipelined  = _isPipelined;

- (id)init
{
	self = [ super init ] ;
	if ( self ) {
		_outputClient = nil ;
		_isPipelined = NO ;
		//data = (CMDataStream*)malloc( sizeof( CMDataStream ) ) ;
		_data = &_staticStream ;		//  v0.80l
		_data->array = nil ;
		_data->userData = 0 ;
		_data->samples = _data->components = 0 ;
		_data->channels = 1 ;
	}
	return self ;
}

- (void)pipeWithClient:(CMPipe*)client
{

	//self = [ self init ] ;
//	if ( self ) {
		_outputClient = client ;
//	}
	//return self ;
}

- (CMPipe*)client
{
	return _outputClient ;
}

- (void)setClient:(CMPipe*)inClient
{
	_outputClient = inClient ;
	_isPipelined = NO ;
}

- (void)setPipelinedClient:(CMPipe*)inClient
{
	_outputClient = inClient ;
	_isPipelined = YES ;
}

- (CMDataStream*)stream
{
	return _data ;
}

//  base class of AudioPipe implements a NOP pipe
//  we simply forward the data to the next stage of the pipeline
- (void)importData:(CMPipe*)pipe
{
	*_data = *[ pipe stream ] ;
	[ self exportData ] ;
}

- (void)importPipelinedData:(CMPipe*)pipe
{
    
	*_data = *[ pipe stream ] ;
	[ self exportData ] ;
}

//  call client's importData method with our data
- (void)exportData
{
	if ( _outputClient ) {
		if ( _isPipelined ) {
            [ _outputClient importPipelinedData:self ] ;
        } else {
            [ _outputClient importData:self ] ;
        }
	}
}

@end
