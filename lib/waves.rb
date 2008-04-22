# from struct import *
# import os, sys
# 
# # RIFF hdr + FMT chunk + DATA chunk
# 
# # -- RIFF hdr -- 
# # CHUNKID       4bytes = "RIFF"
# # CHUNKSIZE     4bytes = 36+data size
# # FORMAT        4bytes = "WAVE"
# 
# # -- FMT chunk --
# # SUBCHUNK1ID   4bytes = "fmt "
# # SUBCHUNK1Size 4bytes = 16 (PCM)
# # AUDIOFORMAT   2bytes = 1 (PCM)
# # NUMCHANNELS   2bytes = 1 (mono), 2 (stereo)
# # SAMPLERATE    4bytes = some sample rate
# # BYTERATE      4bytes = SAMPLERATE * BLOCKALIGN
# # BLOCKALIGN    2bytes = NUMCHANNELS * BITSPERSAMPLE / 8
# # BITSPERSAMPLE 2bytes = 8, 16, 32 etc..
# 
# # -- DATA chunk --
# # SUBCHUNK2ID   4bytes = "data"
# # SUBCHUNK2SIZE 4bytes = NUMSAMPLES * NUMCHANNELS * BITSPERSAMPLE / 8
# # DATA          ....
# 
# # TODO: some kinda callback registration so we can know what's happening
# # during the various steps
# 
# class WAVMaker:
#     def __init__(self, channels = None, samplerate = None, bps = None):
#         self.channels = 1
#         self.samplerate = 22050
#         self.bps = 8
#         self.bufsize = 128
#         if channels:
#             self.channels = int(channels)
#         if samplerate:
#             self.samplerate = int(samplerate)
#         if bps:
#             self.bps = int(bps)
#     
#     def getNumSamplesFromData(self, filename):
#         if os.path.exists(filename):
#             fsize = os.path.getsize(filename)
#             numsamples = (((fsize * 8) / self.channels + 0.0) / self.bps + 0.0)
#             # I dunno, maybe I'll need to pad the file if this is a floaty value?
#             print numsamples
#             return numsamples
# 
#     def makeWAVHeader(self, filename):
#         if os.path.exists(filename):
#             fsize = os.path.getsize(filename)
#             riff = pack(">4c","R","I","F","F")
#             riff += pack("<i",36+fsize)
#             riff += pack(">4c","W","A","V","E")
#             
#             fmt = pack(">4c","f","m","t"," ")
#             
#             self.getNumSamplesFromData(filename)
#             
#             blockalign = self.channels * self.bps / 8
#             byterate = self.samplerate * blockalign
#             
#             fmt += pack("<i2h2i2h",16,1,self.channels,self.samplerate,byterate,blockalign,self.bps)
#         
#             data = pack(">4c","d","a","t","a")
#             data += pack("<i",fsize)
#             
#             return (riff, fmt, data)
#             
#     def getWAVFilename(self, filename):
#         wav_filename = "%s.wav" % filename
#         i = 0
#         while os.path.exists(wav_filename):
#             wav_filename = "%s%03d.wav" % (filename, i)
#             i+=1
#             if i > 999:
#                 raise Exception, "Too many wav files alread for this file"
#         return wav_filename
#     
#     def writeWAVFile(self, filename, header, datafilename):
#         (riff, fmt, datahdr) = header
#         wav_file = file(filename, "w+b")
#         wav_file.write(riff)
#         wav_file.write(fmt)
#         wav_file.write(datahdr)
#         wav_file.flush()
#             
#         data_file = file(datafilename,"rb")
#         data = data_file.read(self.bufsize)
#         while data != "":
#             wav_file.write(data)
#             data = data_file.read(self.bufsize)
#         wav_file.flush()
#         wav_file.close()
#         data_file.close()
# 
#     def makeWAVFile(self, filename):
#         filename = os.path.abspath(filename)
#         if os.path.exists(filename):
#             wav_header = self.makeWAVHeader(filename)
#             wav_filename = self.getWAVFilename(filename)
#             self.writeWAVFile(wav_filename, wav_header, filename)
#     
# def main(fname, channels = None, samplerate = None, bps = None):
#     wm = WAVMaker(channels, samplerate, bps)
#     wm.makeWAVFile(fname)
# 
# if __name__ == '__main__':
#     main(*sys.argv[1:])