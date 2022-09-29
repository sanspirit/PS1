# Run "create_seq_apikeys.py local seq.local" with the second argument as your local seq instance name to run into local seq

import json
import sys
import os
import requests
from pprint import pprint

def set_apikey(url,appname,productname,token,minlevel):
    """
    Create an apikey on seq
    """
    tokenprefix = token[:4]
    apikey_body = {
        "Title": appname,
        "Token": token,
        "TokenPrefix": tokenprefix,
        "InputSettings": {
            "AppliedProperties": [
                {
                    "Name": "App",
                    "Value": appname
                },
                {
                    "Name": "Product",
                    "Value": productname
                }
            ],
            "Filter": {
                "Description": None,
                "DescriptionIsExcluded": False,
                "Filter": None,
                "FilterNonStrict": None
            },
            "MinimumLevel": minlevel,
            "UseServerTimestamps": False,
        },
        "IsDefault": False,
        "OwnerId": None,
        "AssignedPermissions": [
            "Ingest"
        ],
        "Metrics": {
            "ArrivalsPerMinute": 0,
            "InfluxPerMinute": 0,
            "IngestedBytesPerMinute": 0
        }
    }
    data = json.dumps(apikey_body)
    response = requests.post(url, data=data, verify=False)
    pprint(response.json())
    pass

def iterate_applist(applist,seqinst,minlevel):
    """
    iterate through the data list to run the seq api keys in
    """
    url = f'http://{seqinst}/api/apikeys'

    for app in applist:
        appname = app['AppName']
        productname = app['ProductName']
        token = app['Token']

        set_apikey(url=url, appname=appname, productname=productname, token=token, minlevel=minlevel)
    pass

l = sys.argv[1]
if l == 'local':
    if len(sys.argv) != 3:
        raise ValueError('You need to specify the seq instance name like: create_seq_apikeys.py local seq.local')
    else:
        seqinst = sys.argv[2]
    print('local')
    sp = os.path.dirname(os.path.abspath(__file__))
    with open(f'{sp}\\applist_local.json') as applist_file:
        applist = json.load(applist_file)
    minlevel = 'Verbose'
    iterate_applist(applist=applist, seqinst=seqinst, minlevel=minlevel)
else:
    print('notlocal')
    seqinst = get_octopusvariable("Endpoint:Seq")
    minlevel = get_octopusvariable("Seq.LogLevel")
    applist = get_octopusvariable("Seq.AppList")
    applist = json.loads(applist)
    iterate_applist(applist=applist, seqinst=seqinst, minlevel=minlevel)
