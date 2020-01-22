import sys, time
from dnslib import RR, RCODE, QTYPE
from dnslib.server import DNSServer,DNSHandler,BaseResolver,DNSLogger

class OURIP:
    pass

#XXX I think all this could be replaced with dnslib's zoneresolver.py,
#    by giving it fakeroot.hints with our extra records appended.
zone = {
    ('NS', '.'): 'a.root-servers.net.',
    ('A', 'net.'): OURIP(),
    ('A', 'root-servers.net.'): OURIP(),
    ('A', 'a.root-servers.net.'): OURIP(),

    ('A', 'acme-v02.api.letsencrypt.org'): OURIP(),
    ('A', 'acme-staging-v02.api.letsencrypt.org'): OURIP(),

    ('NS', 'boundery.me.'): [ 'ns1.boundery.me.', 'ns1.boundery.me.' ]
    ('A', 'ns1.boundery.me.'): '30.0.1.9',
    ('A', 'ns2.boundery.me.'): '30.0.1.9',
}

class DumbResolver(BaseResolver):
    def resolve(self, request, handler):
        reply = request.reply()
        qname = str(request.q.qname).lower()
        qtype = QTYPE[request.q.qtype]
        print('REQUEST "%s" "%s"' % (qtype, qname))
        recs = zone.get((qtype, qname))
        if recs:
            if type(recs) != list:
                recs = [ recs, ]
            for rec in recs:
                data = sys.argv[1] if type(rec) == OURIP else rec
                for rr in RR.fromZone('%s 60 IN %s %s' % (qname, qtype, data)):
                    print('REPLY WITH: %s' % rr)
                    reply.add_answer(rr)
        else:
            reply.header.rcode = RCODE.NXDOMAIN
        return reply

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise Exception("Requires one argument: address to listen on")
    print("DumbResolver started.")
    resolver = DumbResolver()
    udp_server = DNSServer(resolver, address=sys.argv[1])
    tcp_server = DNSServer(resolver, address=sys.argv[1], tcp=True)
    udp_server.start_thread()
    tcp_server.start_thread()
    while udp_server.isAlive() and tcp_server.isAlive():
        time.sleep(1)
