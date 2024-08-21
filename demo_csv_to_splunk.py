import csv
import sys
import json
import requests
import datetime

filepath = r'C:\Users\david\Downloads\customers-100.csv'

# initialize list to contain csv row dict items
data = []

# get csv rows into list of dicts
with open(filepath, newline='', encoding='utf-8') as csvfile:
    reader = csv.DictReader(csvfile)
    try:
        for row in reader:
            data.append(row)
    except csv.Error as e:
        sys.exit('file {}, line {}: {}'.format(filepath, reader.line_num, e))

# batch writes to Splunk http event collector (hec) in a manner 
# that ensures payload is lower than max content size
hec_max_content_length = 1000000
hec_max_content_length = 3000 # testing
hec_events = []
hec_events_counter = 0
hec_batch_counter = 0

# construct uri and header for post
splunk_uri = 'https://splunk_host:8088/services/collector/event'    
splunk_hec_token = 'blah'
headers = {'Authorization': 'Splunk '+ splunk_hec_token}
    
# iterate through rows to produce event and post in batches
for item in data:
    
    hec_events_counter += 1
    
    # todo:// convert eventTime from string to datetime and then epoch for use in Splunk _time field
    #eventTime_utc = datetime.datetime.strptime(my_event['eventTime'], "%Y-%m-%dT%H:%M:%S.%fZ")
    #eventTime_epoch = (eventTime_utc - datetime(1970, 1, 1)).total_seconds()

    # todo:// append splunk metadata to item
    hec_event = {}
    hec_event['index'] = 'test-index'
    hec_event['source'] = 'test-source'
    hec_event['sourcetype'] = 'test-sourcetype'
    # hec_event['_time'] = eventTime_epoch
    hec_event['event'] = item
       
    hec_events.append(hec_event)
        
    # get size of accumulated list as json
    hec_events_size = len(json.dumps(hec_events))
    
    if hec_events_size >= hec_max_content_length:
        hec_batch_counter += 1
        # commit all but most recent record to batch
        batch = hec_events[:-1]
        print('writing batch: {} to splunk hec having {} events with total size of {} bytes'.format(
            hec_batch_counter,
            len(batch),
            len(json.dumps(batch))            
            )
        )
        # post the event to splunk http event collector endpoint
        #try:
        #    r = requests.post(splunk_uri, data=json.dumps(batch), headers=headers, verify=ca_certs)
        #    r.raise_for_status()
        #except requests.exceptions.HTTPError as err:
        #    raise SystemExit(err)
                
                
        # reset the events list and re-add current item
        hec_events = []
        hec_events.append(hec_event)
    
    # handle condition where we are processing the last record but max content not exceeded
    if hec_events_counter == len(data):
        hec_batch_counter += 1
        batch = hec_events
        print('writing batch: {} to splunk hec having {} events with total size of {} bytes'.format(
            hec_batch_counter,
            len(batch),
            len(json.dumps(batch))            
            )
        )
        # post the event to splunk http event collector endpoint
        #try:
        #    r = requests.post(splunk_uri, data=json.dumps(batch), headers=headers, verify=ca_certs)
        #    r.raise_for_status()
        #except requests.exceptions.HTTPError as err:
        #    raise SystemExit(err)
    
print('last event: {}'.format(batch[-1]))
