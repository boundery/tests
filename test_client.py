import sys, os, shutil, random

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

testuser = 'testuser_%s' % random.randint(0,2**32)

shutil.rmtree('/vagrant/build/screenshots', ignore_errors=True)
os.makedirs('/vagrant/build/screenshots')

d = webdriver.Chrome()
d.set_page_load_timeout(10)
d.implicitly_wait(10) #10s timeout for finding elements.

#Step 1 (Write out SDcard image)
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
try:
    wait = WebDriverWait(d, 60)
    click_here = wait.until(EC.element_to_be_clickable((By.PARTIAL_LINK_TEXT, 'click here')))
except:
    screenshot(d, 'step1_fail')
    raise

screenshot(d, 'step1_done')

os.sync()
os.system('ls -l /mnt')
os.system('sudo umount /mnt')
click_here.click()

#Step 2 (Click to go to boundery.me)
screenshot(d, 'step2')

click_here = d.find_element_by_tag_name('a')
click_here.click()

#Step 3 (Create acct on boundery.me)
screenshot(d, 'step3')

username = d.find_element_by_name('username')
email = d.find_element_by_name('email')
email2 = d.find_element_by_name('email2')
password1 = d.find_element_by_name('password1')
password2 = d.find_element_by_name('password2')
username.send_keys(testuser)
email.send_keys('%s@example.com' % testuser)
email2.send_keys('%s@example.com' % testuser)
password1.send_keys('testpassword')
password2.send_keys('testpassword')
signup = d.find_element_by_xpath('//button')
signup.click()

#Step 4 (Get email link, click it)
screenshot(d, 'step4')
url = None
with open('/vagrant/build/emails/webmaster@boundery.me_%s@example.com' % testuser, 'r') as f:
    for line in f:
        for word in line.split():
            if word.startswith('https://boundery'):
                url = word
if url:
    d.get(url)
else:
    raise Exception("Email didn't contain a valid URL")

#Step 5 (Need to raise privs for VPN establishment)
screenshot(d, 'step5')

click_here = d.find_element_by_tag_name('a')
click_here.click()

#Step 6 (Wait for home server to register).
screenshot(d, 'step6')

try:
    wait = WebDriverWait(d, 120)
    results = wait.until(EC.text_to_be_present_in_element((By.ID, 'results'),
                                                          'Joined secure network.'))
except:
    screenshot(d, 'step6_fail')
    raise

screenshot(d, 'step6_done')

click_here = wait.until(EC.element_to_be_clickable((By.PARTIAL_LINK_TEXT, 'Click here')))
click_here.click()

#Step 7 (Appstore)
screenshot(d, 'step7')

assert('Applications Available to Install' in d.page_source)

#XXX Check that we are in the private network, and not the adhoc.

#XXX Because we short circuit the dyndns NS forward to the pi, need to explicitly
#    check that username.boundery.me gets the right NS destination (30.0.0.150).
#    dig ns nolan.boundery.me. @boundery.me.

if '-d' in sys.argv:
    import code
    code.InteractiveConsole(locals=locals()).interact()

os.system('touch /vagrant/build/linux-pczip-success')
