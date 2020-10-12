import glob


def modify_auth_server_xml():
    fn = "/opt/jans/jetty/auth-server/webapps/auth-server.xml"

    with open(fn) as f:
        txt = f.read()

    with open(fn, "w") as f:
        ctx = {
            "extra_classpath": ",".join([
                j.replace("/opt/jans/jetty/auth-server", ".")
                for j in glob.iglob("/opt/jans/jetty/auth-server/custom/libs/*.jar")
            ])
        }
        f.write(txt % ctx)


if __name__ == "__main__":
    modify_auth_server_xml()
