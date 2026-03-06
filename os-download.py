from os import system, name
import os
import requests
import random
import json
import base64
import pathlib
import requests
import binascii

version_number = "2.7.4"

def base64_decode(b64_string):
    # Define the Base64 character set
    base64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    # Remove any padding ('=')
    b64_string = b64_string.rstrip('=')

    # Convert each Base64 character to its binary representation
    binary_string = ''.join(format(base64_chars.index(c), '06b') for c in b64_string)

    # Split the binary string into bytes (8 bits each)
    byte_values = [binary_string[i:i+8] for i in range(0, len(binary_string), 8)]

    # Convert each byte to a character
    decoded_bytes = bytearray(int(b, 2) for b in byte_values)

    # Return the decoded bytes as a string
    return decoded_bytes.decode('utf-8')

def clear():

    # for windows
    if name == 'nt':
        _ = system('cls')

    # for mac and linux(here, os.name is 'posix')
    else:
        _ = system('clear')

# now call function we defined above

clear()
print("Welcome to the FunnyOS patcher!")
print("")
print("First step, go to https://play.date/devices/, select your playdate, ")
print("and remove it from your account.")
print("")
wait = input("Press Enter after de-registering your device to continue.")
print("")
DEVICE_SERIAL = input("Input your Playdate's serial number in the format of PDUX-YXXXXXX: ")
possiblechars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
indemkey = ""
for x in range(16):
    indemkey = indemkey + random.choice(possiblechars)
response = requests.get("https://play.date/api/v2/device/register/"+DEVICE_SERIAL+"/get", headers={"Idempotency-Key": indemkey})

# Check the status code
respdict = json.loads(response.text)
pin=""
if "detail" in respdict:
    print(respdict["detail"])
if response.status_code != 200:
        exit()
if "pin" in respdict:
    pin = respdict["pin"]
print("")
print("Go to https://play.date/pin and enter the pin:")
print("")
print(pin)
print("")
wait = input("Press Enter after entering your pin to continue.")


print("")

response = requests.get("https://play.date/api/v2/device/register/"+DEVICE_SERIAL+"/complete/get")
respdict = json.loads(response.text)

if "detail" in respdict:
    print(respdict["detail"])
if response.status_code != 200:
    exit()

if "registered" in respdict:

    if not respdict["registered"]:
        print("The pin was not entered.")
        exit()

access_token = ""

if "access_token" in respdict:

    if respdict["access_token"] == "":
        print("Womp Womp")
        exit()
    else:
        access_token = respdict["access_token"]

response = requests.get("https://play.date/api/v2/firmware/?current_version="+version_number, headers={"Authorization": "Token "+access_token})
respdict = json.loads(response.text)

if "detail" in respdict:
    print(respdict["detail"])
if response.status_code != 200:
    exit()

decrypt_key = ""
download_url = ""
decrypt_key = respdict["decryption_key"]
download_url = respdict["url"]
decrypted_key = base64.b64decode(decrypt_key)

print(decrypt_key)

url = download_url
local_filename = os.path.dirname(os.path.abspath(__file__)) + "/PlaydateOS.pdos"

# Send a GET request to the URL
with requests.get(url, stream=True) as response:
    response.raise_for_status()  # Check for request errors
    # Write the file to disk in chunks
    with open(local_filename, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

with open(os.path.dirname(os.path.abspath(__file__)) + "/PlaydateOS.pdkey", 'wb') as output:
    output.write(decrypted_key)

print("")
