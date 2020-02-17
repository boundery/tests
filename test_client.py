import sys, os

import socketserver

from selenium import webdriver
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait

class TCPCmdHandler(socketserver.StreamRequestHandler):
    def handle(self):
        global url
        cmd = self.rfile.readline().decode().split(' ')
        assert(cmd[0] == "BROWSE")
        url = cmd[1]

def screenshot(d, name):
    d.save_screenshot('/vagrant/build/screenshots/%s.png' % name)

with socketserver.TCPServer(('localhost', 9999), TCPCmdHandler, bind_and_activate=False) as server:
    server.allow_reuse_address = True
    server.server_bind()
    server.server_activate()
    server.handle_request()

os.makedirs('/vagrant/build/screenshots', exist_ok=True)

d = webdriver.Chrome()
d.set_page_load_timeout(10)
d.implicitly_wait(10) #10s timeout for finding elements.

#Step 1
print("Navigating to URL:", url)
d.get(url)

ssid_radios = d.find_elements_by_name('ssid')
wired_radio = ssid_radios[-1]
assert(wired_radio.get_attribute('value') == '')
wired_radio.click()

screenshot(d, 'step1')

mount = d.find_element_by_name('mount')
mount.click()
screenshot(d, 'step1_writing')

wait = WebDriverWait(d, 60)
click_here = wait.until(EC.element_to_be_clickable((By.PARTIAL_LINK_TEXT, 'click here')))

screenshot(d, 'step1_done')

os.sync()
os.system('sudo umount /mnt')
click_here.click()

#Step 2
screenshot(d, 'step2')

click_here = d.find_element_by_tag_name('a')
click_here.click()

#Step 3 (boundery.me)



#XXX Because we short circuit the dyndns NS forward to the pi, need to explicitly
#    check that username.boundery.me gets the right NS destination (30.0.0.150).
#    dig ns nolan.boundery.me. @boundery.me.

if '-d' in sys.argv:
    import code
    code.InteractiveConsole(locals=locals()).interact()
