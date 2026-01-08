{{- define "seed-users" -}}
User:
  - ID: 1
    Name: Admin
    Email: 'admin@svtech.com.vn'
    Password: 'P@ssw0rd1'
    Groups:
      - ID: 1
  - ID: 2
    Name: User
    Email: user@svtech.com.vn
    Password: P@ssw0rd2
    Groups:
      - ID: 2
      - ID: 3
  - ID: 3
    Name: Readonly
    Email: readonly@svtech.com.vn
    Password: P@ssw0rd3
    Groups:
      - ID: 3
  - ID: 4
    Name: Datasource manager
    Email: dsmanager@svtech.com.vn
    Password: P@ssw0rd4
    Groups:
      - ID: 4
{{- end -}}