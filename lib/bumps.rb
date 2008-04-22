# from struct import *
# import os, sys, math
# 
# # FILE hdr + IMAGE hdr + COLOR table + PIXEL data
# 
# # -- FILE hdr -- 
# # TYPE          2bytes = "BM"
# # SIZE          4bytes = 14 + 40 + colortable + pixel data
# # RESERVED_1    2bytes = 0
# # RESERVED_2    2bytes = 0
# # PIXEL_OFFSET  4bytes = offest to start of pixel data
# 
# # -- IMAGE chunk --
# # SIZE          4bytes = 40
# # WIDTH         4bytes = width of image
# # HEIGHT        4bytes = height of image
# # PLANES        2bytes = 1
# # BITCOUNT      2bytes = bits per pixel: 1,2,4,8,16,24,32
# #                        NOTE: 16 & 32 mean a weird colour table, don't use them
# # COMPRESSION   4bytes = compression type: 0
# # SIZEIMAGE     4bytes = image size: 0 for uncompressed
# # X_RESOLUTION  4bytes = preferred pixels per meter (X)
# # Y_RESOLUTION  4bytes = preferred pixels per meter (Y)
# # COLOURS_USED  4bytes = number of used colours (0 for 24bit)
# # COLOURS_IMP   4bytes = number of important colours (0 for 24bit)
# 
# # -- COLOR table --
# # Repeat the following for each colour (e.g. BITCOUNT of 8 = 256 colours)
# # Blue          1byte = red value
# # Green         1byte = green value
# # Red           1byte = blue value
# # Unused        1byte = 0
# 
# # -- PIXEL data --
# # Data          .....
# # Scan Lines must be multiples of 4-bytes, so we may have to pad with 
# # 0,1,2 or 3 null bytes for each line in the file.
# # Scan Line = WIDTH * BITCOUNT
# 
# # TODO: some kinda callback registration so we can know what's happening
# # during the various steps
# 
# class BMPMaker:
#     def __init__(self):
#         self.bitcount = 24
#         pass
# 
#     def getPixelCountFromData(self, filename):
#         ''' This function returns the number of pixels that this file 
#             would create for the current bitcount.
#             The return value is a tuple of two items:
#                 1. the pixel count
#                 2. the number of pad bits that need to be added to the
#                    end of the files data to complete the final pixel.'''            
#         if os.path.exists(filename):
#             fsize = os.path.getsize(filename)
#             fsize_in_bits = fsize*8
#             realpixels = (fsize_in_bits / self.bitcount)
#             padforfinalpixel = (fsize_in_bits % self.bitcount)
#             if padforfinalpixel == 0:
#                 return (realpixels, 0)
#             else:
#                 return (realpixels+1, (self.bitcount - padforfinalpixel) / 8)
#     
#     def getWidthAndHeightFromPixels(self, pixels):
#         ''' This function returns the width and height of the image given the 
#             supplied number of pixels.
#             The return value is a 2 part tuple:
#                 1.  A tuple of (Width, Height) in pixels.
#                 2.  The number of pad pixels that have to be added 
#                     to create an image of the returned width and height.
#             The algorithm is to find the square root of the pixel count
#             and if this is not a whole number, we round up and calculate the
#             difference in pixels such that:
#             pad_pixels = square(round_up(sqrt(pixels))) - pixels'''
#         root = int(math.ceil(math.sqrt(pixels)))
#         pad = (root**2) - pixels
#         return ((root,root),pad)
# 
#     def calcColourTableSize(self):
#         if self.bitcount == 24:
#             return 0
#         else:
#             colours = 2 ** self.bitcount
#             return colours * 4
# 
#     def calcScanLinePad(self, width):
#         return (32 - ((width * self.bitcount) % 32))/8
# 
#     def makeBMPHeader(self, img_details):
#         (pixels, finalpixelpadbytes, (width, height), padpixles, linepadbytes) = img_details
#                     
#         bmpsize = 54 #hdr
#         bmpsize += self.calcColourTableSize() # color table
#         offset = bmpsize
#         imgsize = (((width * self.bitcount) / 8) + linepadbytes) * height #pixeldata
#         bmpsize += imgsize 
#         
#         filehdr = pack("<2c","B","M")
#         filehdr += pack("<i",bmpsize)
#         filehdr += pack("<2h",0,0)
#         filehdr += pack("<i",offset)
#         
#         imghdr = pack("<i",40)
#         imghdr += pack("<i",width)
#         imghdr += pack("<i",height)
#         imghdr += pack("<h",1)
#         imghdr += pack("<h",self.bitcount)
#         imghdr += pack("<i",0)
#         imghdr += pack("<i",0)
#         # I can honestly say that whilst I know what these mean, I don't
#         # know if these default values can affect the stored data or not
#         imghdr += pack("<i",96) 
#         imghdr += pack("<i",96)
#         if self.bitcount == 24:
#             imghdr += pack("<2i",0,0)
#         else:
#             imghdr += pack("<2i",2**self.bitcount,0)
#         
#         if self.bitcount == 24:
#             colourtable = None
#         else:
#             colourtable = self.getColourTable()
#         return (filehdr, imghdr, colourtable)
#             
#     def getBMPFilename(self, filename):
#         bmp_filename = "%s.bmp" % filename
#         i = 0
#         while os.path.exists(bmp_filename):
#             bmp_filename = "%s%03d.bmp" % (filename, i)
#             i+=1
#             if i > 999:
#                 raise Exception, "Too many bmp files alread for this file"
#         return bmp_filename
#     
#     def writeBMPFile(self, filename, img_details, header, datafilename):
#         (filehdr, imghdr, colourtable) = header
#         (pixels, finalpixelpadbytes, (width, height), padpixels, linepadbytes) = img_details
#         
#         bmp_file = file(filename, "w+b")
#         bmp_file.write(filehdr)
#         bmp_file.write(imghdr)
#         if colourtable:
#             bmp_file.write(datahdr)
#         bmp_file.flush()
#             
#         data_file = file(datafilename,"rb")
#         
#         
#         linepad = pack("<%dx"%linepadbytes)
#         
#         fetchsize = int((width * self.bitcount) / 8) # I hope this is never a *mung* value due to stupid bitcounts...
#         
#         # write data
#         (data, EOF) = self.__getBytes(data_file, fetchsize)
#         while not EOF:
#             bmp_file.write(data)
#             bmp_file.write(linepad)
#             (data, EOF) = self.__getBytes(data_file, fetchsize)
#         bmp_file.write(data)
#         bmp_file.write(pack("<%dx"%finalpixelpadbytes))
#         bmp_file.flush()
#         
#         #write final padding - I'm pretty sure this *could* go mung for a bitcount of less than a byte
#         pad_data_row = padpixels % width
#         data_row = pack("<%dx"%pad_data_row) + linepad
#         bmp_file.write(data_row)
#         bmp_file.flush()
#         
#         pad_rows = padpixels / width
#         pad_row = pack("<%dx"%((width * self.bitcount) / 8)) + linepad
#         for x in range(pad_rows):
#             bmp_file.write(pad_row)
#         bmp_file.flush()
#         
#         bmp_file.close()
#         data_file.close()
# 
#     def __getBytes(self, file, bytes):
#         data = ""
#         getsize = bytes
#         while (len(data) != bytes):
#             chunk = file.read(getsize)
#             if chunk == "":
#                 return (data,True)
#             else:
#                 data += chunk
#                 getsize = bytes - len(data)
#         return (data,False)
# 
#     def makeBMPFile(self, filename):
#         filename = os.path.abspath(filename)
#         if os.path.exists(filename):
#             (pixels, finalpixelpadbits) = self.getPixelCountFromData(filename)
#             ((width, height), padpixels) = self.getWidthAndHeightFromPixels(pixels)
#             linepadbits = self.calcScanLinePad(width)
#             img_details = (pixels, finalpixelpadbits, (width, height), padpixels, linepadbits)
#             bmp_header = self.makeBMPHeader(img_details)
#             bmp_filename = self.getBMPFilename(filename)
#             self.writeBMPFile(bmp_filename, img_details, bmp_header, filename)
#     
# def main(fname):
#     wm = BMPMaker()
#     wm.makeBMPFile(fname)
# 
# if __name__ == '__main__':
#     main(*sys.argv[1:])