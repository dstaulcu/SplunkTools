Example Splunk Query:

```SPL
index=_internal source="checkSplunkCerts" 
| dedup host confName, specName, cert
| table _time, host, source, confName, specName, cert, expires, daysToExpire, daysToExpireStatus, Subject, confPath
| sort - _time
```
