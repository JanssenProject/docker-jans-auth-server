import glob


def modify_oxauth_xml():
    fn = "/opt/jans/jetty/oxauth/webapps/oxauth.xml"

    with open(fn) as f:
        txt = f.read()

    with open(fn, "w") as f:
        ctx = {
            "extra_classpath": ",".join([
                j.replace("/opt/jans/jetty/oxauth", ".")
                for j in glob.iglob("/opt/jans/jetty/oxauth/custom/libs/*.jar")
            ])
        }
        f.write(txt % ctx)


if __name__ == "__main__":
    modify_oxauth_xml()
