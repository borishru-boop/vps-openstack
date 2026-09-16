SELECT id, hostname, state, left(root_password, 80) AS pwd_prefix, length(root_password) AS pwd_len
FROM vps.instances
WHERE hostname = 'vps-tiql7p';
