
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

    # CONFIGURATION SETTINGS
    sigma_rule_folder = 'C:/Users/david/PycharmProjects/SigmaToSplunk/sigma/rules/windows'
    supported_rule_status = ['stable']  # 'experimental','test','stable','expired'
    supported_rule_status = ['experimental','test','stable','expired']
    prepend_splunk_search = "(index=* AND (sourcetype=XmlWinEventLog OR sourcetype=WinEventLog))"

    # Sigma setup (import backends and pipelines)
    pipeline = sysmon_pipeline()
    backend = SplunkBackend(pipeline)

    # Identify all rule files to possibly process
    if Path(sigma_rule_folder).is_dir():  # True if folder
        sigma_files_gen = Path(sigma_rule_folder).glob('**/*.yml')
        files_on_disk = [x for x in sigma_files_gen if x.is_file()]
        print('Loaded {} yaml files from {}'.format(len(files_on_disk), sigma_rule_folder))
    else:
        raise FileNotFoundError(
            print('No folder exists at {}'.format(sigma_rule_folder))
        )

    # set counter to track applicable rules
    matching_rule_count = 0

    # Iterate through rule files
    for sigma_file in files_on_disk:

        # open the rule file reading
        with sigma_file.open(mode='r') as f:

            try:
                sigma_obj = SigmaCollection.from_yaml(f)
            except:
                continue

            # handle possibility of more than one rule in object
            for rule in sigma_obj.rules:

                # only process rules with desired status
                if str(rule.status) in supported_rule_status:

                    matching_rule_count += 1

                    # some rules do not convert reliably so try this first
                    try:
                        converted_query = backend.convert(sigma_obj)[0]  # should only be one
                    except sigma_exceptions.SigmaConditionError as e:
                        continue
                    except sigma_exceptions.SigmaFeatureNotSupportedByBackendError as e:
                        continue

                    print('\nsigma_file: {}'.format(sigma_file))
                    print('rule_title: {}'.format(rule.title))
                    print('rule_level: {}'.format(rule.level))
                    print('rule_status: {}'.format(rule.status))
                    print('rule_description: {}'.format(rule.description))

                    for tag in rule.tags:
                        print('rule_tag: {}'.format(tag))

                    for ref in rule.references:
                        print('rule_ref: {}'.format(ref))

                    for fp in rule.falsepositives:
                        print('rule_fp: {}'.format(fp))


                    converted_query = prepend_splunk_search + ' ' + converted_query
                    print('rule_query: {}'.format(converted_query))

    print('\nmatching rule count: {}'.format(matching_rule_count))
