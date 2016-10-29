from erlport.erlterms import Atom
from erlport.erlang import call

import json

class SlackBotPlugin(object):
    def __init__(self, cmds):
        self.cmds = cmds

    def plugin_init(self, slackbot, team_state):
        self.slackbot = slackbot
        self.team_state = json.loads(team_state.decode('utf-8'))
        return self

    def target_cmds(self):
        return [Atom(x.encode('utf-8')) for x in self.cmds]

    def do_dispatch_command(self, cmd, args, msg):
        self.dispatch_command(cmd, args.decode('utf-8'),
                              json.loads(msg.decode('utf-8')))
        return self

    def send_message(self, msg, channel):
        call(Atom(b"Elixir.SlackBot"), Atom(b"send_message"), [self.slackbot, msg.encode('utf-8'), channel.encode('utf-8')])
