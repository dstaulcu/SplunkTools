#!/usr/bin/env python
# coding: utf-8

# # Update and extend Splunkbase CSV.
#
# Splunk.com provides an API that allows you to export a list of apps available on Splunkbase.  Exported lists of apps can be uploaded as lookups into Splunk instances that are not connected to the Internet. You can compare output of the "apps" API on search heads to an imported splunkbase lookup file to determine if apps installed on the server have updates available.  This alone is useful for app update planning.
#
# If you are planning a Splunk Enterprise update, it would also be helpful understand the Splunk Enterprise versions supported among apps.  This script scrapes additional information of interest from the app's web page on Splunkbase and includes that in the outputs of the CSV file.  Additional fields include version, filename, splunk versions, and cim versions.

import requests  # to support basic web requests
import json  # to support interaction with JSON structures
import math
import datetime
from bs4 import BeautifulSoup  # to support advanced web page scraping
import re  # to support regular expressions
import pandas as pd  # to support working with CSV file and dataframes
import os.path

# todo - add optional support for use of web proxy
#proxies = {'https': 'http://10.10.10.10'}
#response = requests.get(url,proxies = proxies)


# define path to local catalog file
project_path = 'c:\\apps\\splunkbase_v3'
catalog_path = os.path.join(project_path, 'splunkbase_catalog.csv')

if not (os.path.exists(project_path)):
    os.makedirs(project_path)

# check whether existing local catlog lists.
if not (os.path.exists(catalog_path)):
    # this appears to be the first run, use the modern computing startdate as bookmarkdate
    bookmarkdate = datetime.datetime.fromisoformat('1970-01-01T00:00:00+00:00')

else:

    # read catalog_path CSV structure into dataframe
    splunkbase_catalog_dataframe = pd.read_csv(catalog_path)

    # get bookmarkdate from most recent updated_time value in dataframe
    bookmarkdate = max(splunkbase_catalog_dataframe['updated_time'])

    # convert bookmarkdate value to consistent format
    bookmarkdate = datetime.datetime.fromisoformat(bookmarkdate)

# show the user what bookmarkdate we are moving forward with
print("Bookmark of last update set at {}. We can stop hitting the splunkbase API when entries are older.".format(
    bookmarkdate))


def get_splunk_appinfo(url):
    # input - url to splunkbase webpage for splunk app
    # output - dictionary of app properties scraped from webpage

    # initialize dictionary of function results
    appinfo = dict()
    appinfo['app_version'] = 'unknown'
    appinfo['app_filename'] = 'unknown'
    appinfo['app_splunk_versions'] = 'unknown'
    appinfo['app_cim_versions'] = 'unknown'

    # get webrequest for app page on splunkbase
    page = requests.get(url)
    soup = BeautifulSoup(page.content, 'html.parser')

    # get latest version from first release option value element tag
    version = soup.select('#release-option')
    if version:
        version = version[0]['value']
        appinfo['app_version'] = version

        # construct regex search pattern to find elements of current app version
        pattern = '<sb-release-select class="u.item:1/1@*" sb-selector="release-version" sb-target="' + version + '" u-for="download-modal">'
        pattern = re.escape(pattern)
        pattern = '^' + pattern

        # find element having checksum and extract download filename
        elements = soup.find_all('sb-release-select')
        for element in elements:
            element_string = str(element)
            match = re.match(pattern, element_string, re.IGNORECASE)
            if match:
                if 'checksum' in element_string:
                    # got the element; now extract the file name
                    if match := re.search('checksum \(([^\)]+)', element_string, re.IGNORECASE):
                        app_filename = match.group(1)
                        appinfo['app_filename'] = app_filename

        # find element having splunk releases and extract splunk release versions
        elements = soup.find_all('sb-release-select')
        for element in elements:
            element_string = str(element)
            match = re.match(pattern, element_string, re.IGNORECASE)
            if match:
                if 'Splunk Versions:' in element_string:
                    # got the element; now extract the Splunk versions
                    app_splunk_versions = (re.findall('product/splunk/versions/([^"]+)', element_string))
                    app_splunk_versions = "|".join(app_splunk_versions)
                    appinfo['app_splunk_versions'] = app_splunk_versions

        # find element having splunk releases and extract splunk CIM Versions
        elements = soup.find_all('sb-release-select')
        for element in elements:
            element_string = str(element)
            match = re.match(pattern, element_string, re.IGNORECASE)
            if match:
                if 'CIM Versions:' in element_string:
                    # got the element; now extract the Splunk versions
                    app_cim_versions = (re.findall('apps/#/cim/([^"]+)', element_string))
                    app_cim_versions = "|".join(app_cim_versions)
                    appinfo['app_cim_versions'] = app_cim_versions

    return appinfo


# get first page of results from splunkbase api
url = "https://splunkbase.splunk.com/api/v1/app"
head = {'Content-Type': 'application/json'}
parameters = {'order': 'latest', 'limit': '1', 'offset': '0'}
ret = requests.get(url, params=parameters, headers=head)

if not ret.ok:
    reason = ret.reason
    print("status is not ok with {0}".format(reason))
    quit()

print("web request result {}".format(ret.reason))

# show structure of first result returned from splunkbase api
preview = ret.json()['results'][0]
print(json.dumps(preview, indent=1))

# identify total number of entries contained in first page of splunkbase api response
total_entries = ret.json()['total']

# identify number of pages of splunkbase api enumerate
pages = int((total_entries / 100) + 1)

# display findings
print("Splunkbase has {} entries/results. Looks like we are going to hit the splunkbase api up to {} times.".format(
    total_entries, pages))

# gather app listings from splunkbase pages ordered newest to oldest
results = []  # this is a list that will be populated with lists of dictionaries
for i in range(pages):
    offset = i * 100
    print('getting splunkbase apps - page ' + str(i + 1) + ' of ' + str(pages) + ' [offset=' + str(offset) + ']')
    parameters = {'order': 'latest', 'limit': '100', 'offset': offset}
    ret = requests.get(url, params=parameters, headers=head)
    results.append(ret.json()['results'])

    # break out of loop if last record is older than bookmark date
    last_updated_time = datetime.datetime.fromisoformat(results[-1][-1]['updated_time'])
    if last_updated_time < bookmarkdate:
        print("Last record {} in page is older than bookmark {}. Exiting loop.".format(str(last_updated_time),
                                                                                       str(bookmarkdate)))
        break

# iterate through the dictionaries in lists (aka splunk apps returned across results)
# add entries newer than bookmark date to list named update_list
update_list = []
for result in results:
    for item in result:
        item_updated_time = datetime.datetime.fromisoformat(item['updated_time'])
        # process items newer than bookmark date
        if item_updated_time > bookmarkdate:
            update_list.append(item)
            print('app with update time "{}" added to update_list.'.format(item['updated_time']))

# process each updated app
for item in update_list:
    # leverage function to scrape elements of interest from app page on Splunkweb
    print('working on {}'.format(item['path']))
    app_info = get_splunk_appinfo(item['path'])

    # add returned extended info to dictionary
    item.update(app_info)
    print('added additional app info {}'.format(app_info))

# merge content if updates exist

if len(update_list) > 0:

    # import update_list as dataframe
    update_list_dataframe = pd.DataFrame(update_list)

    # get distinct values of app uinique id from updated_time dataframe
    updated_uid_list = update_list_dataframe['uid'].unique()

    # remove updated records from splunkbase_catalog_dataframe
    for uid in updated_uid_list:
        print('removing record "{}" from splunkbase_catalog_dataframe'.format(uid))
        splunkbase_catalog_dataframe = splunkbase_catalog_dataframe[splunkbase_catalog_dataframe.uid != uid]

    # append updated records to splunkbase_catalog_dataframe
    new_row_count = update_list_dataframe.count(axis='rows')[0]
    print('appending {} update_list_dataframe rows to splunkbase_catalog_dataframe'.format(new_row_count))
    splunkbase_catalog_dataframe = splunkbase_catalog_dataframe.append(update_list_dataframe, ignore_index=True)

    # sort the dataframe by updated_time, descending
    splunkbase_catalog_dataframe = splunkbase_catalog_dataframe.sort_values(by='updated_time', ascending=False)

    # write dataframe to csv
    print('committed updates to catalog_path - {}'.format(catalog_path))
    splunkbase_catalog_dataframe.to_csv(catalog_path, index=False)

# read catalog_path CSV structure into dataframe
splunkbase_catalog_dataframe = pd.read_csv(catalog_path)

# gather summary of data changes
row_count = splunkbase_catalog_dataframe.count(axis='rows')[0]
bookmarkdate = max(splunkbase_catalog_dataframe['updated_time'])
# compute new row count
try:
    new_row_count
except NameError:
    new_row_count = 0

print(
    'Operation complete. Catalog has {} entries.  The most recent entry is {}. {} entries were updated in this session.'.format(
        row_count, bookmarkdate, new_row_count))
