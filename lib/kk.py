import requests

url = "https://api.tomorrow.io/v4/weather/realtime?location=karachi&apikey=m0nWSTMtRvReHl5KIpTX5eYbzx0PSGQY"

headers = {"accept": "application/json"}

response = requests.get(url, headers=headers)

print(response.text)