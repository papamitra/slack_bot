
from slackbotplugin import SlackBotPlugin

class PyEcho(SlackBotPlugin):
    def __init__(self):
        super(PyEcho, self).__init__(["pyecho"])

    def dispatch_command(self, cmd, args, msg):
        self.send_direct_message(args, msg["user"])
