import requests
from requests import Response
from requests.exceptions import  Timeout
import http
from bs4 import BeautifulSoup
import re
import concurrent.futures

"""
todo:
•	Accept command line parameters for products to download
•	Accept command line parameters for folder to download pdf document to
•	Identify name of file to download from server response
•	Figure out why requests library takes so long to get pdf file compared to browser-based download of same target
    (tried session, tried headers, tried stream & chunked-writes, trying sleep between tx)
"""


def load_url(download):

    pdf_download_url, file_path = download

    print('-downloading url: {} to: {}'.format(pdf_download_url, file_path))

    # open in binary mode
    with open(file_path, "wb") as file:
        # get request
        response = s.get(pdf_download_url)
        # write to file
        file.write(response.content)


def get_splunkdoc_products():
    print('Getting list of splunk products.')

    url = "https://docs.splunk.com/Documentation/Splunk"
    page = s.get(url)
    soup = BeautifulSoup(page.content, "html.parser")

    elements = soup.select('#product-select')
    pattern = 'value=\"([^\"]+)\">(.*)\</option>'

    elements_dict = {}

    for element in elements[0].contents:
        element = str(element)
        match = re.match(pattern, element, re.IGNORECASE)
        if match := re.search(pattern, element, re.IGNORECASE):
            key = match.group(1)

            value = match.group(2)
            value = value.replace('<sup>', '')
            value = value.replace('</sup>', '')

            elements_dict[key] = value

    return elements_dict

def get_splunkdoc_versions(product):
    url = "https://docs.splunk.com/Documentation/" + product
    page = s.get(url)
    soup = BeautifulSoup(page.content, "html.parser")

    elements = soup.select('#version-select')
    pattern = 'value=\"([^\"]+)\">(.*)\</option>'

    elements_dict = {}

    for element in elements[0].contents:
        element = str(element)
        match = re.match(pattern, element, re.IGNORECASE)
        if match := re.search(pattern, element, re.IGNORECASE):
            key = match.group(1)

            value = match.group(2)
            value = value.replace('<sup>', '')
            value = value.replace('</sup>', '')

            elements_dict[key] = value

    return elements_dict



# create session object for re-use
s = requests.Session()
# toggle value from 0 to 1 to enable http request debugging
http.client.HTTPConnection.debuglevel = 0

download_path = 'C:\Apps\splunkdocs'
#my_products = get_splunkdoc_products()
my_products = ['Splunk', 'Forwarder', 'DSP', 'ES', 'SOARonprem', 'UBA', 'MC', 'SSE', 'ITSI', 'DBX']


download_list = []

for product in my_products:

    print('working on product: {}'.format(product))

    versions = (get_splunkdoc_versions(product))

    for version in versions:
        if 'latest release' in versions[version]:

            print('-found latest release version: {}'.format(version))

            # get page for specified product and version as soup
            url = 'https://docs.splunk.com/Documentation/' + product + '/' + version
            page = s.get(url)
            soup = BeautifulSoup(page.content, "html.parser")

            # process links listing documentation for product and version
            for i in soup.find_all(href=re.compile('^/Documentation/' + product + '/' + version + '/')):

                # get page associated with the document
                page = s.get('https://docs.splunk.com' + (i.attrs['href']))
                soup = BeautifulSoup(page.content, "html.parser")

                # get the links on document page associated pdfbook (effectively excluding topic)
                for j in soup.find_all(href=re.compile('title=Documentation:.*&action=pdfbook&[^\&]+&product=')):

                    # construct the download url
                    href = j.attrs['href']
                    pdf_download_url = 'https://docs.splunk.com' + href

                    # construct the download filename
                    document = (href.split(":"))[2]
                    file_name = product + '-' + version + '-' + document + '.pdf'
                    file_path = download_path + '\\' + file_name

                    print('-adding document {} to download list'.format(document))
                    download_list.append((pdf_download_url, file_path))


# We can use a with statement to ensure threads are cleaned up promptly
with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
    # Start the load operations and mark each future with its URL
    future_to_url = {executor.submit(load_url, download_item): download_item for download_item in download_list}
    for future in concurrent.futures.as_completed(future_to_url):
        download_item = future_to_url[future]
        try:
            data = future.result()
        except Exception as exc:
            print('%r generated an exception: %s' % (download_item, exc))
        else:
            pass
