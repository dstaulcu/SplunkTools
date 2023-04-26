
from sigma.rule import SigmaRule
from sigma.pipelines.sysmon import sysmon_pipeline
from sigma.backends.splunk import SplunkBackend
from sigma.collection import SigmaCollection
import sigma.exceptions as sigma_exceptions
from datetime import date
from pathlib import Path
import xml.etree.cElementTree as ET
import logging

"""
Note:
forked from https://github.com/askkemp/Sigma-to-Massive-Slunk-Dashboard

setup:
create project folder
git clone https://github.com/SigmaHQ/sigma.git into project folder
git clone https://github.com/SigmaHQ/pySigma-backend-splunk.git & copy .\sigma subfolder into .\project\sigma folder
git clone https://github.com/SigmaHQ/pySigma-pipeline-sysmon.git  & copy .\sigma subfolder into .\project\sigma folder
"""

if __name__ == '__main__':

    sigma_rule_folder = 'C:/Users/david/PycharmProjects/SigmaToSplunk/sigma/rules/windows/'
    sigma_rule_folder = 'C:/Users/david/PycharmProjects/SigmaToSplunk/sigma/rules/'


    supported_rule_folders = ['auditd','windows']
    supported_rule_folders = ['windows']
    supported_rule_status = ['experimental','test','stable','expired']
    supported_rule_status = ['stable']
    prepend_splunk_search = "(index=* AND (sourcetype=XmlWinEventLog OR sourcetype=WinEventLog))"  # set to "" if nothing is wanted

    # Determine files to parse
    if Path(sigma_rule_folder).is_dir():  # True if folder
        sigma_files_gen = Path(sigma_rule_folder).glob('**/*.yml')
        files_on_disk = [x for x in sigma_files_gen if x.is_file()]
        print('Loaded {} yaml files from {}'.format(len(files_on_disk), sigma_rule_folder))
    else:
        raise FileNotFoundError(
            f'No folder exists at {sigma_rule_folder}. Edit CONFIGURE ME section of this script and specify path to Sigma rules folder.')

    # Sigma setup
    pipeline = sysmon_pipeline()
    backend = SplunkBackend(pipeline)

    for sigma_file in files_on_disk:

        for folder in supported_rule_folders:

            if folder in str(sigma_file):

                with sigma_file.open() as f:

                    try:
                        sigma_obj = SigmaCollection.from_yaml(f)
                    except:
                        logging.error(f'Exception occured when converting sigma collection item from yaml {sigma_file}')
                        continue

                    try:
                        converted_query = backend.convert(sigma_obj)[0]  # should only be one
                    except sigma_exceptions.SigmaConditionError as e:
                        logging.error(f'The following exception occured when processing {sigma_file}: {e}')
                        continue
                    except sigma_exceptions.SigmaFeatureNotSupportedByBackendError as e:
                        logging.error(f'The following exception occured when processing {sigma_file}: {e}')
                        continue

                    rule_status = str(sigma_obj.rules[0].status)

                    if str(rule_status) in supported_rule_status:
                        print('\nsigma_file: {}'.format(sigma_file))
                        print('rule_status: {}'.format(rule_status))

                        converted_query = prepend_splunk_search + ' ' + converted_query

                        print('converted_query: {}'.format(converted_query))
