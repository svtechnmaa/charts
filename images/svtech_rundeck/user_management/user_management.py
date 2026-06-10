#!/opt/.pyenv/versions/automation36/bin/python

import sqlite3
import hashlib
import subprocess
import logging
import sys
import os
import re
import time
import pprint
import requests
import json
from requests.auth import HTTPBasicAuth
import argparse
import configparser

config = configparser.ConfigParser()
config.read('/etc/rundeck/user_management/config.conf')
rundeck_auth_file = config["rundeck"]["rundeck_auth_file"]
rundeck_admin_acl_file = config["rundeck"]["rundeck_admin_acl_file"]

nagvis_auth_file = config["nagvis"]["nagvis_auth_file"]
nagvis_salt_string = config["nagvis"]["nagvis_salt_string"]

grafana_host = config["grafana"]["grafana_host"]
grafana_port = config["grafana"]["grafana_port"]
grafana_user = config["grafana"]["grafana_user"]
grafana_password = config["grafana"]["grafana_password"]

thruk_permission_file = config["thruk"]["thruk_permission_file"]
thruk_pass_file = config["thruk"]["thruk_htpasswd_file"]

def PRINT_W_TIME ( message = "" ,
                   timestamp = time.strftime ( '%x' ) + "  " + time.strftime ( '%X' ) ) :
    #timestamp = "avoiding error, break-fix"
    for lines in message.splitlines ( ) :
        print ("{}\t{}".format(timestamp,message))

def CREATE_EXPORT_DIR ( directory = "./" ) :
    # type: (directory) -> string
    """CREATE DIR"""
    if not os.path.exists ( directory ) :
        os.makedirs ( directory )
        logging.debug ( 'Created new directory: ' + directory )
    else :
        logging.debug ( 'Directory already existed ' + directory )
    return directory

def LOGGER_INIT ( log_level = logging.INFO ,
                  log_file = 'unconfigured_log.log' ,
                  file_size = 2 * 1024 * 1024 ,
                  file_count = 2 ,
                  shell_output = False ,
                  log_file_mode = 'a' ,
                  log_format = '%(asctime)s %(levelname)s %(funcName)s(%(lineno)d)     %(message)s',
                  print_log_init = False) :
    try :
        main_logger = logging.getLogger ( )
        main_logger.setLevel ( log_level )
        # add a format handler
        log_formatter = logging.Formatter ( log_format )

    except Exception as e :
        PRINT_W_TIME ( "Exception  when format logger cause by:    {}".format( e ) )
        logging.error ( "Exception  when format logger cause by:    {}".format( e ) )

    log_dir = os.path.dirname( os.path.abspath(log_file) )
    if print_log_init == True: PRINT_W_TIME("Creating log directory ()".format(log_dir))


    try :
        main_logger.handlers = [] #init blank handler first otherwise the stupid thing will create a few and print to console
        main_logger.propagate = False #Only need this if basicConfig is used

        # add a rotating handler
        from logging.handlers import RotatingFileHandler
        log_rorate_handler = RotatingFileHandler ( log_file ,
                                                   mode = log_file_mode ,
                                                   maxBytes = file_size ,
                                                   backupCount = file_count ,
                                                   encoding = None ,
                                                   delay = 0 )
        log_rorate_handler.setFormatter ( log_formatter )
        log_rorate_handler.setLevel ( log_level )
        #add the rotation handler only
        main_logger.addHandler ( log_rorate_handler )

    except Exception as e :
        PRINT_W_TIME ( "Exception when creating main logger handler cause by:    {}".format( e ) )
        logging.error ( "Exception when creating main logger handler cause by:    {}".format( e ) )

    try :
        CREATE_EXPORT_DIR ( log_dir ) # Only do this after the 2 above step, otherwise fcking main_logger will spam debug log to stdout
        if shell_output == True :
            stdout_log_handler = logging.StreamHandler ( sys.stdout )
            stdout_log_handler.setFormatter ( log_formatter )
            stdout_log_handler.setLevel ( log_level )
            #add the stdout handler properly
            main_logger.addHandler ( stdout_log_handler )
    except Exception as e :
        PRINT_W_TIME ( "Exception when creating log directory and setup log stdout handler cause by:    {}".format( e ) )
        logging.error ( "Exception when creating log directory and setup log stdout handler cause by:    {}".format ( e ) )

    if print_log_init == True: PRINT_W_TIME("Done, logging level " + log_level + " to " + os.path.abspath(log_file))


class NagvisUser():
    def __init__(self):
        self.data = {}
        self.sqlite3_file = nagvis_auth_file
        # self.php_file = "/opt/SVTECH-Junos-Automation/module_utils/user_management/generate_sha1_hash.php"
        self.salt_string = nagvis_salt_string

    def connection(self):
        try:
            conn = sqlite3.connect(self.sqlite3_file)
            return conn
        except Exception as e:
            logging.exception(e)
            sys.exit()

    def generate_hash_via_php(self,
                              password="",
                              salt_string=""):
        try:
            # proc = subprocess.Popen("sudo php {} {} {}".format(php_file, password, salt_string), shell=True, stdout=subprocess.PIPE)
            # hash_string = proc.stdout.read().decode()
            string = salt_string + password
            hash_string = hashlib.sha1(string.encode())
            return hash_string.hexdigest()

        except Exception as e:
            logging.exception(e)
            sys.exit()

    def set_user2roles(self, conn, username, role):
        try:
            userId = ""
            roleId = ""
            get_userId = conn.execute("SELECT userId FROM users where name='{}';".format(username)).fetchall()
            if get_userId != []:
                userId = get_userId[0][0]

            get_roleId = conn.execute("SELECT roleId FROM roles where name='{}';".format(role)).fetchall()
            if get_roleId != []:
                roleId = get_roleId[0][0]

            conn.execute("INSERT INTO users2roles(userId, roleId) VALUES ({},{})".format(userId, roleId))
            conn.commit()
            logging.info("Set Permission for Nagvis user: <{}> successfully !".format(username))

        except Exception as e:
            logging.info("Fail to Set Permission for Nagvis user: <{}> !".format(username))
            logging.exception(e)
            sys.exit()

    def add_user(self, username, password, role):
        """ Add user """
        try:
            conn = self.connection()
            check_user_exist = conn.execute("SELECT name FROM users where name='{}';".format(username)).fetchall()

            if check_user_exist != []:
                logging.error("Fail to Create Nagvis User <{}>. User already exist !".format(username))
                conn.close()
                sys.exit()
            else:
                hash_string = self.generate_hash_via_php(password = password,
                                                        salt_string = self.salt_string)

                conn.execute("INSERT INTO users(name, password) VALUES ('{}','{}')".format(username, hash_string))
                conn.commit()
                logging.info("Create Nagvis user: <{}> successfully !".format(username))

                if role == "User":
                    self.set_user2roles(conn, username, "Users (read-only)")
                elif role == "Editor":
                    self.set_user2roles(conn, username, "Managers")
                elif role == "Admin":
                    self.set_user2roles(conn, username, "Administrators")

                conn.close()
        except Exception as e:
            logging.exception(e)
            sys.exit()

    def delete_user(self, username):
        """ Delete user """
        try:
            conn = self.connection()
            check_user_exist = conn.execute("SELECT name FROM users where name='{}';".format(username)).fetchall()

            if check_user_exist == []:
                logging.error("Fail to Delete User <{}>. User is not exists !".format(username))
                conn.close()
                # sys.exit()
            else:
                userId = ""
                get_userId = conn.execute("SELECT userId FROM users where name='{}';".format(username)).fetchall()
                if get_userId != []:
                    userId = get_userId[0][0]

                conn.execute("DELETE FROM users WHERE name='{}'".format(username))
                conn.execute("DELETE FROM users2roles WHERE userId={}".format(userId))

                conn.commit()
                conn.close()
                logging.info("Delete Nagvis user: <{}> successfully !".format(username))
        except Exception as e:
            logging.exception(e)
            # sys.exit()


    def change_password(self, username, new_password):
        """ Change Password """
        try:
            conn = self.connection()
            check_user_exist = conn.execute("SELECT name FROM users where name='{}';".format(username)).fetchall()

            if check_user_exist == []:
                logging.error("Fail to Change Password Nagvis User <{}>. User is not exists !".format(username))
                conn.close()
                sys.exit()
            else:
                hash_string = self.generate_hash_via_php(password = new_password,
                                                        salt_string = self.salt_string)
                conn.execute("UPDATE users SET password='{}' WHERE name='{}'".format(hash_string, username))
                conn.commit()
                conn.close()
                logging.info("Change Password Nagvis user: <{}> successfully !".format(username))
        except Exception as e:
            logging.exception(e)
            sys.exit()



class GrafanaUser(object):
    def __init__(self):
        self.ip = grafana_host
        self.port = grafana_port
        self.admin_user = grafana_user
        self.admin_password = grafana_password
        self.pre_url    = 'http://{}:{}'.format(self.ip, self.port)
        self.headers    = {"Content-Type":"application/json"}
        self.auth       = HTTPBasicAuth(self.admin_user, self.admin_password)

    def getUserInfo(self, username):
        """ Get user """
        path = "/api/users/lookup"
        params = { "loginOrEmail": username }
        url = "{}{}".format(self.pre_url, path)
        response = requests.get(url,
                                    headers = self.headers,
                                    auth = self.auth,
                                    params = params)
        result = json.loads(response.text)
        return result

    def set_permission(self, username, role):

        try:
            userInfo = self.getUserInfo(username)
            if 'id' not in userInfo:
                logging.error("Fail to Set Permission for Grafana user: <{}>. User is not exists !".format(username))
                # sys.exit()
            else:
                userID = userInfo["id"]
                path = "/api/org/users/{}".format(str(userID))
                url = "{}{}".format(self.pre_url, path)
                if role == "User":
                    data = '{"role": "Viewer"}'
                elif role == "Editor":
                    data = '{"role": "Editor"}'
                elif role == "Admin":
                    data = '{"role": "Admin"}'

                set_permission_user = requests.patch(url,
                                            headers = self.headers,
                                            auth = self.auth,
                                            data = data)
                result = json.loads(set_permission_user.text)
                if set_permission_user.status_code == 200:
                    logging.info("Set Permission for Grafana user: <{}> successfully !".format(username))
                else:
                    logging.error("Fail to Set Permission for Grafana user: <{}> !".format(username))

        except Exception as e:
            logging.exception(e)
            # sys.exit()

    def add_user(self, username, password, role):
        """ Add user """

        try:
            path = "/api/admin/users"
            data = {
                        "name": "User",
                        "email": "{}@local".format(username),
                        "login": username,
                        "password": password,
                    }

            url = "{}{}".format(self.pre_url, path)
            create_user = requests.post(url,
                                        headers = self.headers,
                                        auth = self.auth,
                                        json = data)
            result = json.loads(create_user.text)
            if create_user.status_code == 200:
                logging.info("Create Grafana user: <{}> successfully !".format(username))
            elif create_user.status_code == 500:
                logging.error("Fail to create Grafana user: <{}>. User already exists !".format(username))
                sys.exit()

            self.set_permission(username, role)

        except Exception as e:
            logging.exception(e)
            sys.exit()


    def delete_user(self, username):
        """ Delete user """

        try:
            userInfo = self.getUserInfo(username)
            if 'id' not in userInfo:
                logging.error("Fail to Delete Grafana user: <{}>. User is not exists !".format(username))
                # sys.exit()
            else:
                userID = userInfo["id"]
                path = "/api/admin/users/{}".format(str(userID))
                url = "{}{}".format(self.pre_url, path)
                delete_user = requests.delete(url,
                                            headers = self.headers,
                                            auth = self.auth)
                result = json.loads(delete_user.text)
                if delete_user.status_code == 200:
                    logging.info("Delete Grafana user: <{}> successfully !".format(username))

        except Exception as e:
            logging.exception(e)
            # sys.exit()

    def change_password(self, username, new_password):
        """ Change Password """

        try:
            userInfo = self.getUserInfo(username)
            if 'id' not in userInfo:
                logging.error("Fail to Change Password Grafana user: <{}>. User is not exists !".format(username))
                sys.exit()
            else:
                userID = userInfo["id"]
                path = "/api/admin/users/{}/password".format(str(userID))
                data = {"password": new_password}
                url = "{}{}".format(self.pre_url, path)
                update_user = requests.put(url,
                                            headers = self.headers,
                                            auth = self.auth,
                                            json = data)
                result = json.loads(update_user.text)
                if update_user.status_code == 200:
                    logging.info("Change Password Grafana user: <{}> successfully !".format(username))

        except Exception as e:
            logging.exception(e)
            sys.exit()


class RundeckUser():
    def __init__(self):
        self.config_file = rundeck_auth_file
        self.admin_acl_file = rundeck_admin_acl_file

    def getListUser(self):
        list_user = []
        with open(self.config_file, "r") as file:
            readlines = file.readlines()
            for line in readlines:
                if ":" in line:
                    split_line = line.split(",")
                    user_and_pass = split_line[0]
                    user = user_and_pass.split(":")[0]
                    list_user.append(user)
        return list_user

    # def set_admin_permission(self, username):
    #     try:
    #         list_username = []
    #         with open(self.admin_acl_file, 'r') as admin_acl_file:
    #             read_file = admin_acl_file.readlines()

    #             for line in read_file:
    #                 if "username" in line:
    #                     regex_username = re.findall(r"\[(.*)\]", line.replace(" ", ""))
    #                     if regex_username[0] != "":
    #                         list_username = regex_username[0].split(",")
    #                         break

    #         list_username.append(username)
    #         new_list_username_string = str(list_username).replace("'", "").replace("\"", "")

    #         # with open(self.admin_acl_file, 'w') as write_admin_acl_file:
    #         #     for line in read_file:
    #         #         if "username" in line:
    #         #             string = "{}{}\n".format("  username: ", new_list_username_string)
    #         #             write_admin_acl_file.write(string)
    #         #         else:
    #         #             write_admin_acl_file.write(line)

    #         # logging.info("Set Admin Permission for Rundeck user: <{}> successfully !".format(username))

    #     except Exception as e:
    #         logging.error("Fail to Set Permission for Rundeck user: <{}> !".format(username))
    #         logging.exception(e)
    #         sys.exit()

    def add_user(self, username, password, role):
        """ Add user """
        try:
            list_user = self.getListUser()
            if username in list_user:
                logging.error("Fail to create Rundeck user: <{}>. User already exists !".format(username))
                sys.exit()
            else:
                with open(self.config_file, "a+") as file:
                    file.write("{}:{},user\n".format(username, password))
                    logging.info("Create Rundeck user: <{}> successfully !".format(username))

            # if role == "Admin":
            #     self.set_admin_permission(username)

        except Exception as e:
            logging.exception(e)
            sys.exit()

    def delete_user(self, username):
        """ Delete user """

        try:
            list_user = self.getListUser()
            if username not in list_user:
                logging.error("Fail to Delete Rundeck user: <{}>. User is not exists !".format(username))
                # sys.exit()
            else:
                delete_line = ""
                with open(self.config_file, "r") as read_file:
                    readlines = read_file.readlines()
                    data = readlines[:]
                    for line in readlines:
                        line_split = line.split(",")
                        user_pass = line_split[0].split(":")
                        user = user_pass[0]

                        if username == user:
                            delete_line = line

                with open(self.config_file, "w") as write_file:
                    for each_line in data:
                        if delete_line == each_line:
                            pass
                        else:
                            write_file.write(each_line)
                logging.info("Delete Rundeck user: <{}> successfully !".format(username))

        except Exception as e:
            logging.exception(e)
            # sys.exit()

    def change_password(self, username, new_password):
        """ Change Password """
        try:
            list_user = self.getListUser()
            if username not in list_user:
                logging.error("Fail to Change Password Rundeck user: <{}>. User is not exists !".format(username))
                sys.exit()

            def change_pass(data, line, user, new_pass):
                new_line = user + ":" + new_pass + "," + "user"
                with open(self.config_file, "w+") as open_file:
                    for each_line in data:
                        if line == each_line:
                            open_file.write(new_line + "\n")
                        else:
                            open_file.write(each_line)

            with open(self.config_file, "r") as file:
                readlines = file.readlines()
                data = readlines[:]

                for line in readlines:
                    line_split = line.split(",")
                    user_pass = line_split[0].split(":")
                    user = user_pass[0].replace("\n", "")
                    if user == username:
                        change_pass(data, line, user, new_password)

            logging.info("Change Password Rundeck user: <{}> successfully !".format(username))

        except Exception as e:
            logging.exception(e)
            # sys.exit()

class ThrukUser(object):
    def __init__(self):
        self.thruk_pass_file = thruk_pass_file

    def getListUser(self):
        list_user = []
        with open(self.thruk_pass_file, "r") as file:
            readlines = file.readlines()
            for line in readlines:
                if ":" in line:
                    split_line = line.split(",")
                    user_and_pass = split_line[0]
                    user = user_and_pass.split(":")[0]
                    list_user.append(user)
        return list_user

    def add_user(self, username, password, role):
        """ Add user """
        try:
            list_user = self.getListUser()
            if username in list_user:
                logging.error("Fail to Create Thruk user: <{}>. User already exists !".format(username))
                sys.exit()
            else:
                cmd = "htpasswd -b -c /var/tmp/thruk_pass.log " + str(username)+ ' ' + str(password)
                login = subprocess.check_output(cmd, shell=True)

                f = open("/var/tmp/thruk_pass.log", "r")
                value = f.readlines()
                f.close()

                with open(self.thruk_pass_file, "a") as myfile:
                    myfile.write(str(value[0]))
                    myfile.close()  
                cmd = "rm -f /var/tmp/thruk_pass.log"
                subprocess.check_output(cmd, shell=True) 
                logging.info("Create Thruk user: <{}> successfully !".format(username)) 
                    
                def add_permission(regex):
                    for i in regex:
                        with open(thruk_permission_file, "r") as myfile:
                            f = myfile.read()
                            file = re.search( i, f)
                            myfile.close()
                        with open(thruk_permission_file, "w") as myfile:
                            if file.group(2)== None:
                                myfile.write(re.sub( i, str(username), f))
                                myfile.close()
                            elif file.group(2)!= None:
                                myfile.write(re.sub( i, file.group(2) + "," + str(username), f))
                                myfile.close()

                if role == "User":
                    regex = [ r"(?<=(authorized_for_read_only=))(.*)" , 
                            r"(?<=(authorized_for_all_services=))(.*)" , 
                            r"(?<=(authorized_for_all_hosts=))(.*)" ]
                    add_permission(regex)
                    logging.info("Set Permission for Thruk user: <{}> successfully !".format(username))
                elif role == "Admin":
                    regex = [ r"(?<=(authorized_for_admin=))(.*)" ]
                    add_permission(regex)
                    logging.info("Set Permission for Thruk user: <{}> successfully !".format(username))
                elif role == "Editor":
                    regex = [ r"(?<=(authorized_for_system_information=))(.*)" ,
                            r"(?<=(authorized_for_configuration_information=))(.*)", 
                            r"(?<=(authorized_for_all_services=))(.*)" , 
                            r"(?<=(authorized_for_all_hosts=))(.*)"]
                    add_permission(regex) 
                    logging.info("Set Permission for Thruk user: <{}> successfully !".format(username))
                else:
                    logging.error("Fail to Set Permission for Thruk user: <{}> !".format(username))    
        except Exception as e:
            logging.exception(e)
            sys.exit()

    def delete_user(self, username):
        """ Add user """

        try:
            list_user = self.getListUser()
            if username not in list_user:
                logging.error("Fail to Delete Thruk user: <{}>. User is not exists !".format(username))
                # sys.exit()
            else:
                regex = str(username) + ":" + ".*"+ "\\n"
                with open(self.thruk_pass_file, "r") as myfile:
                    f = myfile.read()
                with open(self.thruk_pass_file, "w") as myfile:
                    myfile.write(re.sub( regex, "", f))
                    myfile.close()
                logging.info("Delete Thruk user: <{}> successfully !".format(username))

        except Exception as e:
            logging.exception(e)
            # sys.exit()


    def change_password(self, username, new_password):
        """ Add user """
        try:
            list_user = self.getListUser()
            if username not in list_user:
                logging.error("Fail to Change Password Thruk user: <{}>. User is not exists !".format(username))
                sys.exit()
            else:
                cmd = "htpasswd -b -c /var/tmp/thruk_pass.log " + str(username)+ ' ' + str(new_password)
                login = subprocess.check_output(cmd, shell=True)

                f = open("/var/tmp/thruk_pass.log", "r")
                value = f.readlines()
                f.close()

                regex = str(username) + ":" + ".*"+ "\\n"
                with open(self.thruk_pass_file, "r") as myfile:
                    f = myfile.read()
                with open(self.thruk_pass_file, "w") as myfile:
                    myfile.write(re.sub( regex, str(value[0]), f))
                    myfile.close()
                cmd = "rm -f /var/tmp/thruk_pass.log"
                subprocess.check_output(cmd, shell=True)
                logging.info("Change Password Thruk user: <{}> successfully !".format(username))

        except Exception as e:
            logging.exception(e)
            # sys.exit()


if __name__=="__main__":
    cmdline = argparse.ArgumentParser(description="Global User Managemnet")
    cmdline.add_argument("-rundeck", help="Rundeck User Action", action='store_true')
    cmdline.add_argument("-grafana", help="Grafana User Action", action='store_true')
    cmdline.add_argument("-nagivs", help="Nagvis User Action", action='store_true')

    cmdline.add_argument("-add", help="Action Add User", action='store_true')
    cmdline.add_argument("-change", help="Action Change Password", action='store_true')
    cmdline.add_argument("-delete", help="Action Delete User", action='store_true')

    cmdline.add_argument("-u", help="Input Username", action='store')
    cmdline.add_argument("-p", help="Input Password", action='store')

    # cmdline.add_argument("-admin_user", help="Admin User", action='store')
    # cmdline.add_argument("-admin_password", help="Admin Password", action='store')

    cmdline.add_argument("-role", help="User Role", action='store')

    args = cmdline.parse_args()

    LOGGER_INIT("INFO", "./user_management.log", print_log_init = False,shell_output= True)

    if args.add and args.u and args.p and args.role:
        RundeckUser().add_user(args.u, args.p, args.role)
        NagvisUser().add_user(args.u , args.p, args.role)
        GrafanaUser().add_user(args.u, args.p, args.role)
        ThrukUser().add_user(args.u, args.p, args.role)


    if args.change and args.u and args.p:
        RundeckUser().change_password(args.u, args.p)
        NagvisUser().change_password(args.u , args.p)
        GrafanaUser().change_password(args.u, args.p)
        ThrukUser().change_password(args.u, args.p)


    if args.delete and args.u:
        RundeckUser().delete_user(args.u)
        NagvisUser().delete_user(args.u)
        GrafanaUser().delete_user(args.u)
        ThrukUser().delete_user(args.u)




# NagvisUser().connection()
# NagvisUser().add_user("hahaha", "hahaha", "Admin")
# NagvisUser().delete_user("hahaha")
# NagvisUser().change_password("ha_test1", "12345")


# conn = sqlite3.connect("/usr/share/nagvis/etc/auth.db")
# rows = conn.execute('SELECT * FROM users2roles;').fetchall()
# # conn.execute("DELETE FROM users2roles WHERE userId=9")
# # conn.commit()
# for row in rows:
#     print(row)



# GrafanaUser().getUserInfo("juniper")
# GrafanaUser("grafanaadmin", "grafanaadmin").delete_user("hahaha")
# GrafanaUser("grafanaadmin", "grafanaadmin").add_user("hahaha", "hahaha", "User")
# GrafanaUser().change_password("haha", "12345")
# GrafanaUser("grafanaadmin", "grafanaadmin").delete_user("hahaha")

# RundeckUser().delete_user("ha_test")
# RundeckUser().add_user("ha_test", "12345", "Admin")
# RundeckUser().change_password("ha_test", "1234567")
# RundeckUser().set_admin_permission("ha_test")
