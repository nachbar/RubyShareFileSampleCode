# RubyShareFileSampleCode
This is based on the sample Ruby code posted on api.sharefile.com from https://api.sharefile.com/rest/samples/ruby.aspx

This is modified to demonstrate Chunked uploads, and is based on the report at https://community.sharefilesupport.com/citrixsharefile/topics/-missing-parameters-response-from-threaded-chunkuri-raw-file-upload-which-parameters-am-i-missing?topic-reply-list%5Bsettings%5D%5Bfilter_by%5D=all&topic-reply-list%5Bsettings%5D%5Bpage%5D=1#reply_16161574

Thanks to Michael Berrier of ShareFile for his help getting this to work.  However, any errors are my own.

To use this (I use Terminal on a Mac with Ruby 2.2.0):

First, modify the code with your own credentials at the end of the file.

Then, start the Terminal, and then, start irb (the Interactive Ruby Shell) and type:
```
require './sharefilesamplecode'
```
(you must include the './', or whatever applies to your operating system, or else irb will look for a gem named sharefilesamplecode)  If everything is OK, you will download the file and folder names in your root, including the ID's, which you can use to construct the upload calls.

Then, you should be able to upload files by calling the routines.  For example:
```
upload_file_one_chunk $token, 'foh5f824-79ad-4665-8351-3625853cea32', '/Users/username/work/YourPDF.pdf'
```
