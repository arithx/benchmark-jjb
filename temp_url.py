import hmac
from hashlib import sha1
from sys import argv
from time import time

if len(argv) != 2:
  print "Syntax: <file_name>"
else:
  seconds = 60*60*24*30
  key = "BenchmarkLogs123"
  method = "GET"
  url = "https://storage101.dfw1.clouddrive.com/v1/MossoCloudFS_d932a517-efe3-48a7-8edb-d4490fde8350/logs/{0}".format(argv[1])
  method = method.upper()
  base_url, object_path = url.split('/v1/')
  object_path = '/v1/' + object_path
  seconds = int(seconds)
  expires = int(time() + seconds)
  hmac_body = '%s\n%s\n%s' % (method, expires, object_path)
  sig = hmac.new(key, hmac_body, sha1).hexdigest()
  print '%s%s?temp_url_sig=%s;temp_url_expires=%s' % \
      (base_url, object_path, sig, expires)
