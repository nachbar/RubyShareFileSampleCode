require "net/https"
require "uri"
require "rubygems"
require "json"
 
# Copyright (c) 2014 Citrix Systems, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a 
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation 
# the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

# Modified by James Nachbar

# The functions in this file will make use of the ShareFile API v3 to show some of the basic
# operations using GET, POST, PATCH, DELETE HTTP verbs. See api.sharefile.com for more information.
#
# Requirements:
# 
# rubygems, json modules
#
# functions were tested with ruby 2.2.0
# some HTTP verbs were not available in versions prior to 1.9.3, and default file/string encoding changed with 2.0.
#
# Authentication
#
# OAuth2 password grant is used for authentication. After the token is acquired it is sent an an
# authorization header with subsequent API requests. 
#
# Exception / Error Checking:
# 
# For simplicity, exception handling has not been added.  Code should not be used in a production environment.
 
=begin
Authenticate via username/password. Returns json token object.
 
Args:
string hostname - hostname like "myaccount.sharefile.com"
string client_id - OAuth2 client_id key
string client_secret - OAuth2 client_secret key 
string username - my@user.name
string password - my password

Returns:
token - a hash of the JSON returned
=end
def authenticate hostname, client_id, client_secret, username, password
    uri_str = "https://#{hostname}/oauth/token"
    uri = URI.parse uri_str
    puts uri
 
    body_data = {"grant_type"=>"password", "client_id"=>client_id, "client_secret"=>client_secret,
                 "username"=>username, "password"=>password}
   
    http = Net::HTTP.new uri.host, uri.port
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
    request = Net::HTTP::Post.new uri.request_uri 
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = URI.encode_www_form(body_data)
   
    response = http.request request
    puts "#{response.code} #{response.message}"
    token = nil
    if response.kind_of? Net::HTTPSuccess
      token = JSON.parse response.body
    end
    return token
end

=begin
Get the Authorization Header, given the token returned by authenticate

Args:
hash token - containing the returned access_token in token['access_token']

Returns:
The text of the token itself, to be added to the Authorization header
=end
def get_authorization_header token
  #return {"Authorization"=>"Bearer #{token['access_token']}"}
  return "Bearer #{token['access_token']}"
end


# Returns hostname to use for this subdomain.  The token contains Control Planes for API and for Account (apicp and appcp)
# but the API Documentation does not say when they apply, and the ShareFile API gives the following for the hostname
def get_hostname token
    return "#{token['subdomain']}.sf-api.com"
end
 
=begin
Get the root level Item for the provided user. To retrieve Children the $expand=Children
parameter can be added.
 
Args: 
array token json acquired from authenticate function
boolean get_children - retrieve Children Items if true, default is false
=end
def get_root token, get_children=false
  uri_str = "https://#{get_hostname(token)}/sf/v3/Items"
  if get_children
   uri_str += "?$expand=Children"
  end
  uri = URI.parse uri_str
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  request = Net::HTTP::Get.new uri.request_uri
  request["Authorization"] = get_authorization_header(token)
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess
    root = JSON.parse response.body
    puts "#{root['Id']} #{root['CreationDate']} #{root['Name']}"
    if root["Children"]
      for child in root["Children"]
        puts "#{child['Id']} #{child['CreationDate']} #{child['Name']}"
      end
    end
    return root
  end
end
 
=begin
Get a single Item by Id.
 
Args: 
array token json acquired from authenticate function
string item_id - an item id 
=end
def get_item_by_id token, item_id
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Items(#{item_id})"
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token   
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess
    item = JSON.parse response.body
    puts "#{item['Id']} #{item['CreationDate']} #{item['Name']}"
  end
end
 
=begin
Get a folder using some of the common query parameters that are available. This will
add the expand, select parameters. The following are used:
 
expand=Children to get any Children of the folder
select=Id,Name,Children/Id,Children/Name,Children/CreationDate to get the Id, Name of the folder 
and the Id, Name, CreationDate of any Children
 
Args:
array token json acquired from authenticate function
string item_id - a folder id 
=end
def get_folder_with_query_parameters(token, item_id)
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Items(#{item_id})?$expand=Children&$select=Id,Name,Children/Id,Children/Name,Children/CreationDate"
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token   
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess
    root = JSON.parse response.body
    puts "#{root['Id']} #{root['Name']}"
    if root["Children"]
      for child in root["Children"]
        puts "#{child['Id']} #{child['CreationDate']} #{child['Name']}"
      end
    end
  end  
end
 
=begin
Create a new folder in the given parent folder.
 
Args:
array token json acquired from authenticate function
string parent_id - the parent folder in which to create the new folder 
string name - the folder name
string description - the folder description
=end
def create_folder token, parent_id, name, description
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Items(#{parent_id})/Folder"
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
 
  folder = {"Name"=>name, "Description"=>description}
   
  request = Net::HTTP::Post.new uri.request_uri 
  request["Authorization"] = get_authorization_header(token)
  request["Content-Type"] = "application/json"
  request.body = folder.to_json
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess
    new_folder = JSON.parse response.body
    puts "Created New Folder: #{new_folder['Id']}"
  end
end
 
=begin
Update the name and description of an Item.
 
Args:
array token json acquired from authenticate function
string item_id - the id of the item to update 
string name - the item name
string description - the item description
=end
def update_item token, item_id, name, description
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Items(#{item_id})"
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
 
  item = {"Name"=>name, "Description"=>description}
   
  request = Net::HTTP::Patch.new uri.request_uri 
  request["Content-Type"] = "application/json"
  request["Authorization"] = get_authorization_header(token)
  request.body = item.to_json
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess
    updated_item = JSON.parse response.body
    puts "Updated Item: #{updated_item['Id']}"
  end 
end
 
=begin
Delete an Item by Id.
 
Args:
array token json acquired from authenticate function
string item_id - the id of the item to delete
=end
def delete_item token, item_id
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Items(#{item_id})"
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  request = Net::HTTP::Delete.new(uri.request_uri)
  request["Authorization"] = get_authorization_header(token)
   
  response = http.request request
  puts "#{response.code} #{response.message}"
  if response.kind_of? Net::HTTPNoContent
    puts "Deleted Item"
  end
end
 
=begin
Downloads a single Item. If downloading a folder the local_path name should end in .zip.
 
Args:
array token json acquired from authenticate function
string item_id - the id of the item to download 
string local_path - where to download the item to, like "c:\\path\\to\\the.file"
=end
def download_item token, item_id, local_path
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Items(#{item_id})/Download"
  puts uri 
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token   
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.header['location']
      redirect_uri = URI.parse(response.header['location'])
      redirect_http = Net::HTTP.new redirect_uri.host, redirect_uri.port
      redirect_http.use_ssl = true
      redirect_http.verify_mode = OpenSSL::SSL::VERIFY_PEER
       
      redirect_request = Net::HTTP::Get.new redirect_uri.request_uri
      response = redirect_http.request redirect_request
      puts "#{response.code} #{response.message}"
 
      #resp, data = http.get(url.path, nil)
  end

  #puts "body length is #{response.body.length}"
   
  open(local_path, "wb") do |file|
      file.write(response.body)
  end
end
 
=begin
Uploads a File using the Standard upload method with a multipart/form mime encoded POST.
 
Args:
array token json acquired from authenticate function
string folder_id - where to upload the file
string local_path - the full path of the file to upload, like "c:\\path\\to\\file.name"
=end
def upload_file token, folder_id, file_path
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Items(#{folder_id})/Upload"
  puts uri 
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token   
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess  
    upload_config = JSON.parse response.body
    if upload_config["ChunkUri"]
      upload_response = multipart_form_post upload_config['ChunkUri'], file_path
      puts "Upload Complete: #{upload_response.code} #{upload_response.message}"
    end
  end
end
 
=begin
Does a multipart form post upload of a file to a url.
 
Args:
string url - the url to upload file to
string filepath - the complete file path of the file to upload like, "c:\path\to\the.file
 
Returns:
the http response 
=end
def multipart_form_post url, file_path  
  newline = "\r\n"
  filename = File.basename(file_path)
  boundary = "----------#{Time.now.nsec}"
     
  uri = URI.parse(url)
   
  post_body = []
  post_body << "--#{boundary}#{newline}"
  post_body << "Content-Disposition: form-data; name=\"File1\"; filename=\"#{filename}\"#{newline}"
  post_body << "Content-Type: application/octet-stream#{newline}"
  post_body << "#{newline}"
  post_body << File.read(file_path)
  post_body << "#{newline}--#{boundary}--#{newline}"
   
  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = post_body.join
  request["Content-Type"] = "multipart/form-data, boundary=#{boundary}"
  request['Content-Length'] = request.body().length
 
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  response = http.request request
  return response
end
 
=begin
Get the Client users in the Account.
 
Args:
array token json acquired from authenticate function
=end
def get_clients token
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Accounts/GetClients"
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
   
  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token   

  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess
    feed = JSON.parse response.body
    if feed["value"]
      for client in feed["value"]
        puts "#{client['Id']} #{client['Email']}"
      end
    end 
  end
end
 
=begin
Create a Client user in the Account.
 
Args:
array token json acquired from authenticate function
string email - email address of the new user
string firstname - first name of the new user
string lastname - last name of the new user
string company - company of the new user
string clientpassword - password of the new user
boolean canresetpassword - user preference to allow user to reset password
boolean canviewmysettings - user preference to all user to view 'My Settings'
=end
# JMN - if there is a problem, returns 400 Bad Request, and json of the error is returned in the body, like:
#{"code":"BadRequest",
# "message":{
#   "lang":"en-US",
#   "value":"Invalid Argument User.Passwords must contain at least 8 characters, containing at least 1 number, 1 upper case letter, and 1 lower case letter."},
# "reason":"BadRequest"}
def create_client token, email, firstname, lastname, company, clientpassword, canresetpassword, canviewmysettings
  uri = URI.parse "https://#{get_hostname(token)}/sf/v3/Users"
  puts uri
   
  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
 
  client = {"Email"=>email, "FirstName"=>firstname, "LastName"=>lastname, "Company"=>company,
            "Password"=>clientpassword, "Preferences"=>{"CanResetPassword"=>canresetpassword, "CanViewMySettings"=>canviewmysettings},
            "DefaultZone" => {"Id"=> 'zp68549224-de4a-4a48-b1df-9868ff3fc9'}}

  request = Net::HTTP::Post.new uri.request_uri #,initheader = {"Content-Type"=>"application/json"})
  request["Content-Type"] = "application/json"
  request['Authorization'] = get_authorization_header token  
  request.body = client.to_json
  puts client.to_json
   
  response = http.request request
  puts "#{response.code} #{response.message}"
 
  if response.kind_of? Net::HTTPSuccess
    new_client = JSON.parse response.body
    puts "Created New Client: #{new_client['Id']}"
  else
    error = JSON.parse response.body
    puts "Error: #{error['message']['value']}"
  end 
end

=begin
Uploads a File using the Threaded upload method with raw data in the POST.  It divides the file
into two chunks, for demonstration purposes.

Args:
hash token json acquired from authenticate function
string folder_id - where to upload the file, like 'foh5f824-79ad-4665-8351-3625853ced5d'
string file_path - the full path of the file to upload, like '/Users/username/work/MyFIle.pdf'
=end
def upload_file_chunked_raw token, folder_id, file_path

  filename = File.basename(file_path)
  file_content = File.open(file_path, 'rb') { |io| io.read } # must open in binary mode
  file_length = file_content.length
  uri = URI.parse "https://#{get_hostname token}/sf/v3/Items(#{folder_id})/Upload?method=threaded&raw=True&" +
                    "fileName=#{filename}&overwrite=True&" +
                    "fileSize=#{file_length}&" +
                    "filehash=#{Digest::MD5.hexdigest(file_content)}&" +
                    "threadCount=1"
  puts uri

  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token

  response = http.request request
  puts "#{response.code} #{response.message}"
  puts "#{response.body}"
  if response.kind_of? Net::HTTPSuccess
    hash = JSON.parse response.body
    puts "file length is #{file_length}"
    length_first = file_length / 2
    length_second = file_length - length_first
    first_part = file_content[0 ... length_first]
    second_part = file_content[length_first ... file_length]

    chunk_uri = hash['ChunkUri']
    finish_uri_string = hash['FinishUri']

    uri_string_first = chunk_uri + "&index=0&byteOffset=0&hash=#{Digest::MD5.hexdigest(first_part)}"
    puts "uri_string_first is #{uri_string_first}"
    uri_first = URI.parse uri_string_first
    request_first = Net::HTTP::Post.new uri_first
    request_first['Authorization'] = get_authorization_header token
    request_first['Content-Length'] = length_first
    puts "request_first['Content-Length']: #{request_first['Content-Length']}"
    request_first['Content-Type'] = 'application/octet-stream'
    request_first.body = first_part

    http_first = Net::HTTP.new uri_first.host, uri_first.port
    http_first.use_ssl = true
    http_first.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response_first = http_first.request request_first
    puts "response_first: #{response_first.code} #{response_first.message}"
    puts "response_first: #{response_first.body}"


    uri_string_second = chunk_uri + "&index=1&byteOffset=#{length_first}&hash=#{Digest::MD5.hexdigest(second_part)}"
    puts "uri_string_second is #{uri_string_second}"
    uri_second = URI.parse uri_string_second
    request_second = Net::HTTP::Post.new uri_second
    request_second['Authorization'] = get_authorization_header token
    request_second['Content-Length'] = length_second
    request_second['Content-Type'] = 'application/octet-stream'
    request_second.body = second_part

    http_second = Net::HTTP.new uri_second.host, uri_second.port
    http_second.use_ssl = true
    http_second.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response_second = http_second.request request_second
    puts "response_second: #{response_second.code} #{response_second.message}"
    puts "response_second: #{response_second.body}"

    puts "finish_uri_string is #{finish_uri_string}"
    uri_finish = URI.parse finish_uri_string
    request_finish = Net::HTTP::Get.new uri_finish.request_uri
    request_finish['Authorization'] = get_authorization_header token
    http_finish = Net::HTTP.new uri_finish.host, uri_finish.port
    http_finish.use_ssl = true
    http_finish.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response_finish = http_finish.request request_finish
    puts "response_finish: #{response_finish.code} #{response_finish.message}"
    puts "response_finish: #{response_finish.body}"

  end
end


=begin
Uploads a File using the Standard upload method with raw data in the POST.

Args:
hash token json acquired from authenticate function
string folder_id - where to upload the file, like 'foh5f824-79ad-4665-8351-3625853ced5d'
string file_path - the full path of the file to upload, like '/Users/username/work/MyFIle.pdf'
=end
def upload_file_raw token, folder_id, file_path
  filename = File.basename(file_path)
  file_content = File.open(file_path, 'rb') { |io| io.read }
  file_length = file_content.length
  uri = URI.parse "https://#{get_hostname token}/sf/v3/Items(#{folder_id})/Upload?method=standard&raw=True&" +
                    "fileName=#{filename}&overwrite=True&" +
                    "fileSize=#{file_length}&" +
                    "filehash=#{Digest::MD5.hexdigest(file_content)}"
  puts uri

  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token

  response = http.request request
  puts "#{response.code} #{response.message}"
  puts "#{response.body}"
  if response.kind_of? Net::HTTPSuccess
    json_response = response.body
    hash = JSON.parse json_response
    puts "file length is #{file_length}"

    chunk_uri = hash['ChunkUri']

    upload_uri_string = chunk_uri
    puts "upload_uri_string is #{upload_uri_string}"
    upload_uri = URI.parse upload_uri_string
    request_upload = Net::HTTP::Post.new upload_uri
    request_upload['Authorization'] = get_authorization_header token
    request_upload['Content-Length'] = file_length
    request_upload['Content-Type'] = 'application/octet-stream'
    request_upload.body = file_content
    puts "upload body length is #{request_upload.body.length}"

    http_upload = Net::HTTP.new upload_uri.host, upload_uri.port
    http_upload.use_ssl = true
    http_upload.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response_upload = http_upload.request request_upload
    puts "response_upload: #{response_upload.code} #{response_upload.message}"
    puts "response_upload: #{response_upload.body}"


  end
end


=begin
Uploads a File using the Threaded upload method with raw data in the POST.  It uses only a single chunk.
The advantage is that it gets back the ID of the file that was created, which is not available in the
Standard upload method.

Args:
hash token json acquired from authenticate function
string folder_id - where to upload the file, like 'foh5f824-79ad-4665-8351-3625853ced5d'
string file_path - the full path of the file to upload, like '/Users/username/work/MyFIle.pdf'
=end
def upload_file_one_chunk token, folder_id, file_path

  filename = File.basename(file_path)
  file_content = File.open(file_path, 'rb') { |io| io.read }
  file_length = file_content.length
  uri = URI.parse "https://#{get_hostname token}/sf/v3/Items(#{folder_id})/Upload?method=threaded&raw=True&" +
                    "fileName=#{filename}&overwrite=True&" +
                    "fileSize=#{file_length}&" +
                    "filehash=#{Digest::MD5.hexdigest(file_content)}&" +
                    "threadCount=1"
  puts uri

  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token

  response = http.request request
  puts "#{response.code} #{response.message}"
  puts "#{response.body}"
  if response.kind_of? Net::HTTPSuccess
    json_response = response.body
    hash = JSON.parse json_response
    puts "file length is #{file_length}"
    chunk_uri = hash['ChunkUri']
    finish_uri_string = hash['FinishUri']

    uri_string_single = chunk_uri + "&index=0&byteOffset=0&hash=#{Digest::MD5.hexdigest(file_content)}"
    puts "uri_string_single is #{uri_string_single}"
    uri_single = URI.parse uri_string_single
    request_single = Net::HTTP::Post.new uri_single
    request_single['Authorization'] = get_authorization_header token
    request_single['Content-Length'] = file_length
    puts "request_single['Content-Length']: #{request_single['Content-Length']}"
    request_single['Content-Type'] = 'application/octet-stream'
    request_single.body = file_content
    puts "request_single.body length is #{request_single.body.length}"

    http_single = Net::HTTP.new uri_single.host, uri_single.port
    http_single.use_ssl = true
    http_single.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response_single = http_single.request request_single
    puts "response_single: #{response_single.code} #{response_single.message}"
    puts "response_single: #{response_single.body}"

    puts "finish_uri_string is #{finish_uri_string}"
    uri_finish = URI.parse finish_uri_string
    request_finish = Net::HTTP::Get.new uri_finish.request_uri
    request_finish['Authorization'] = get_authorization_header token
    http_finish = Net::HTTP.new uri_finish.host, uri_finish.port
    http_finish.use_ssl = true
    http_finish.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response_finish = http_finish.request request_finish
    puts "response_finish: #{response_finish.code} #{response_finish.message}"
    puts "response_finish: #{response_finish.body}"
  end
end

=begin
Uploads a File using the Threaded upload method with multipart form data in the POST.  It divides the file
into two chunks, for demonstration purposes.

Args:
hash token json acquired from authenticate function
string folder_id - where to upload the file, like 'foh5f824-79ad-4665-8351-3625853ced5d'
string file_path - the full path of the file to upload, like '/Users/username/work/MyFIle.pdf'
=end
def upload_file_chunked_multipart token, folder_id, file_path

  filename = File.basename(file_path)
  file_content = File.open(file_path, 'rb') { |io| io.read }
  file_length = file_content.length
  uri = URI.parse "https://#{get_hostname token}/sf/v3/Items(#{folder_id})/Upload?method=threaded&raw=false&" +
                    "fileName=#{filename}&overwrite=True&fileSize=#{file_length}"
  puts uri

  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  request = Net::HTTP::Get.new uri.request_uri
  request['Authorization'] = get_authorization_header token

  response = http.request request
  puts "#{response.code} #{response.message}"
  puts "#{response.body}"
  if response.kind_of? Net::HTTPSuccess
    hash = JSON.parse response.body
    puts "file length is #{file_length}"
    length_first = file_length / 2
    chunk_uri = hash['ChunkUri']
    first_part = file_content[0 ... length_first]
    second_part = file_content[length_first ... file_length]

    uri_first = chunk_uri + "&index=0&byteOffset=0&hash=#{Digest::MD5.hexdigest(first_part)}"
    puts "uri_first is #{uri_first}"
    response_first = multipart_form_post_chunk uri_first, first_part, filename
    puts "response_first: #{response_first.code} #{response_first.message}"
    puts "response_first: #{response_first.body}"

    uri_second = chunk_uri + "&index=1&byteOffset=#{length_first}&hash=#{Digest::MD5.hexdigest(second_part)}"
    puts "uri_second is #{uri_second}"
    response_second = multipart_form_post_chunk uri_second, second_part, filename
    puts "response_second: #{response_second.code} #{response_second.message}"
    puts "response_second: #{response_second.body}"

    finish_uri_string = hash['FinishUri']
    puts "finish_uri_string is #{finish_uri_string}"
    uri_finish = URI.parse finish_uri_string
    request_finish = Net::HTTP::Get.new uri_finish.request_uri
    request_finish['Authorization'] = get_authorization_header token
    http_finish = Net::HTTP.new uri_finish.host, uri_finish.port
    http_finish.use_ssl = true
    http_finish.verify_mode = OpenSSL::SSL::VERIFY_PEER

    response_finish = http_finish.request request_finish
    puts "response_finish: #{response_finish.code} #{response_finish.message}"
    puts "response_finish: #{response_finish.body}"

  end
end

=begin
Creates and sends the multipart form used by the previous routine.

Args:
string url The url string created from ChunkUri, with indes, byteOffset, and hash added
string bytes_to_send  The actual bytes to send
string filename  The filename to send to our uploader
=end
def multipart_form_post_chunk url, bytes_to_send, filename
  newline = "\r\n"
  boundary = "----------#{Time.now.nsec}"

  uri = URI.parse(url)

  post_body = []
  post_body << "--#{boundary}#{newline}"
  post_body << "Content-Disposition: form-data; name=\"Filedata\"; filename=\"#{filename}\"#{newline}"
  post_body << "Content-Type: application/octet-stream#{newline}"
  post_body << "Content-Length: #{bytes_to_send.length}#{newline}"
  post_body << "#{newline}"
  post_body << bytes_to_send
  post_body << "#{newline}--#{boundary}--#{newline}"

  request = Net::HTTP::Post.new(uri.request_uri)
  request.body = post_body.join
  request["Content-Type"] = "multipart/form-data, boundary=#{boundary}"
  request['Content-Length'] = request.body().length

  http = Net::HTTP.new uri.host, uri.port
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER

  response = http.request request
  return response
end

hostname = 'yourcompanydomain.sharefile.com'
username = "sharefileuser@example.com"
password = 'yourpassword'
client_id = 'yourclientid'
client_secret = 'yourclientsecret'
 
$token = authenticate(hostname, client_id, client_secret, username, password)
if $token
    get_root($token, true)
end
