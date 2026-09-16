SELECT root_password_enc IS NOT NULL AS has_pwd, length(root_password_enc::text) AS pwd_len
FROM vps.instance_credentials
WHERE instance_id = '4a73bc67-ac56-4e09-940e-17e14f8d1df4';
