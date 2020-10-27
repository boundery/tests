import sys, os
import smtpd
import asyncore

class FakeSMTPServer(smtpd.SMTPServer):
    def process_message(self, peer, mail_from, rcpt_tos, data, **kwargs):
        filename = os.path.join(sys.argv[1], '%s_%s' % (mail_from, ','.join(rcpt_tos)))
        with open(filename, 'wb') as f:
            f.write(data)
        print('Wrote email to %s' % filename)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print('Usage: %s <email_storage_directory>', file=sys.stderr)
        exit(10)
    server = FakeSMTPServer(('0', 587), None)
    asyncore.loop()
