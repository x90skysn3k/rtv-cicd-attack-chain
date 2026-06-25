/* Replace cloudtrail_logs with your Athena table name. */

SELECT
  eventtime,
  awsregion,
  sourceipaddress,
  useridentity.accountid,
  useridentity.arn,
  useridentity.sessioncontext.sessionissuer.arn AS session_issuer,
  requestparameters,
  responseelements
FROM cloudtrail_logs
WHERE eventsource = 'sts.amazonaws.com'
  AND eventname = 'AssumeRoleWithWebIdentity'
  AND json_extract_scalar(requestparameters, '$.roleArn') LIKE '%rtv-demo-oidc-role%'
ORDER BY eventtime DESC;

SELECT
  eventtime,
  awsregion,
  useridentity.arn,
  useridentity.sessioncontext.sessionissuer.arn AS session_issuer,
  json_extract_scalar(requestparameters, '$.secretId') AS secret_id,
  sourceipaddress
FROM cloudtrail_logs
WHERE eventsource = 'secretsmanager.amazonaws.com'
  AND eventname = 'GetSecretValue'
  AND (
    useridentity.arn LIKE '%assumed-role/rtv-demo-oidc-role/%'
    OR useridentity.sessioncontext.sessionissuer.arn LIKE '%rtv-demo%'
  )
ORDER BY eventtime DESC;

SELECT
  eventtime,
  awsregion,
  useridentity.arn,
  useridentity.sessioncontext.sessionissuer.arn AS session_issuer,
  eventsource,
  eventname,
  requestparameters
FROM cloudtrail_logs
WHERE (
    eventsource = 'lambda.amazonaws.com'
    AND eventname IN ('CreateFunction', 'UpdateFunctionCode')
  )
  OR (
    eventsource = 'events.amazonaws.com'
    AND eventname IN ('PutRule', 'PutTargets')
  )
ORDER BY eventtime DESC;

SELECT
  eventtime,
  awsregion,
  useridentity.arn,
  useridentity.sessioncontext.sessionissuer.arn AS session_issuer,
  json_extract_scalar(requestparameters, '$.roleArn') AS target_role,
  sourceipaddress
FROM cloudtrail_logs
WHERE eventsource = 'sts.amazonaws.com'
  AND eventname = 'AssumeRole'
  AND (
    useridentity.arn LIKE '%rtv-demo%'
    OR json_extract_scalar(requestparameters, '$.roleArn') LIKE '%elevated-chain-target%'
  )
ORDER BY eventtime DESC;
