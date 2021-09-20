#!/usr/bin/env python3
# http://selenium-python.readthedocs.io/

from selenium import webdriver
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.common.by import By
from selenium.webdriver.support.select import Select
import base64
import os
import shutil
import pymysql.cursors

BITRIX_ARCHIVE = "/bitrix-20.0.180.tgz"
BITRIX_VERSION = "20.0.180"

INSTALLER_URL = lambda: "http://{}/".format(os.environ["DOMAIN_NAME"])
ADMIN_URL = lambda: "http://{}/bitrix/admin".format(os.environ["DOMAIN_NAME"])
APP_TITLE = lambda: os.environ["APP_TITLE"]
ADMIN_EMAIL = lambda: os.environ["ADMIN_EMAIL"]
ADMIN_USERNAME = lambda: os.environ["ADMIN_USERNAME"]
ADMIN_PASSWORD = lambda: os.environ["ADMIN_PASSWORD"]
DB_HOST = lambda: os.environ["DB_HOST"]
DB_USER = lambda: os.environ["DB_USER"]
DB_PASSWORD = lambda: os.environ["DB_PASSWORD"]
DB_NAME = lambda: os.environ["DB_NAME"]
WAIT_DELAY = lambda: int(os.getenv("WAIT_DELAY", "60"))

def main():
    print("Renaming old Bitrix tables, if any")
    connection = pymysql.connect(host=DB_HOST(), user=DB_USER(), password=DB_PASSWORD(), db=DB_NAME())
    with connection.cursor() as cursor:
        cursor.execute("SHOW TABLES")
        for table in [r[0] for r in cursor.fetchall() if r[0].startswith("b_")]:
            cursor.execute("RENAME TABLE {0} TO old_{0}".format(table))

    print("Unpacking Bitrix")
    shutil.unpack_archive(BITRIX_ARCHIVE)

    try:
        driver = webdriver.PhantomJS()
        driver.get(INSTALLER_URL())

        print("Skipping first page")
        driver.find_element_by_name("StepNext").click()

        print("Accepting license")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.ID, "agree_license_id")))
        driver.find_element_by_id("agree_license_id").click()
        driver.find_element_by_name("StepNext").click()

        print("Declining registration")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.ID, "lic_key_variant")))
        driver.find_element_by_id("lic_key_variant").click()
        driver.find_element_by_name("StepNext").click()

        print("Skipping 'requirements' page")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.NAME, "StepNext")))
        driver.find_element_by_name("StepNext").click()

        print("Submitting 'create database' form")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.NAME, "__wiz_host")))
        db_host_field = driver.find_element_by_name("__wiz_host")
        db_host_field.clear()   # Bitrix installer sets 'localhost' here by default
        db_host_field.send_keys(DB_HOST())
        driver.find_element_by_name("__wiz_user").send_keys(DB_USER())
        driver.find_element_by_name("__wiz_password").send_keys(DB_PASSWORD())
        db_field = driver.find_element_by_name("__wiz_database")
        db_field.clear()   # Bitrix installer sets 'sitemanager' here by default
        db_field.send_keys(DB_NAME())
        Select(driver.find_element_by_xpath('//*[@id="step-content"]/table/tbody/tr[8]/td[2]/select')).select_by_value("innodb")
        driver.find_element_by_name("StepNext").click()

        print("Waiting for installation")
        WebDriverWait(driver, WAIT_DELAY() * 3).until(EC.element_to_be_clickable((By.NAME, "__wiz_login")))

        print("Submitting 'create admin' form")
        login_field = driver.find_element_by_name("__wiz_login")
        login_field.clear() # Bitrix installer sets 'admin' here by default
        login_field.send_keys(ADMIN_USERNAME())
        driver.find_element_by_name("__wiz_admin_password").send_keys(ADMIN_PASSWORD())
        driver.find_element_by_name("__wiz_admin_password_confirm").send_keys(ADMIN_PASSWORD())
        driver.find_element_by_name("__wiz_email").send_keys(ADMIN_EMAIL())
        driver.find_element_by_name("StepNext").click()

        print("Submitting 'select wizard' form")
        WebDriverWait(driver, WAIT_DELAY() * 3).until(EC.element_to_be_clickable((By.ID, "id_radio_bitrix:demo")))
        driver.find_element_by_id("id_radio_bitrix:demo").click()
        driver.find_element_by_name("StepNext").click()

        print("Skipping 'wizard' first page")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.NAME, "StepNext")))
        driver.find_element_by_name("StepNext").click()

        print("Submitting 'select design' form")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.ID, "web20")))
        driver.find_element_by_id("web20").click()
        driver.find_element_by_name("StepNext").click()

        print("Skipping 'select colorscheme' form")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.NAME, "StepNext")))
        driver.find_element_by_name("StepNext").click()

        print("Submitting 'site data' form")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.NAME, "__wiz_company_name")))
        site_name_field = driver.find_element_by_name("__wiz_company_name")
        site_name_field.clear() # Bitrix installer sets 'Моя компания' by default
        site_name_field.send_keys(APP_TITLE())
        driver.find_element_by_name("StepNext").click()

        print("Unchecking all 'services' and finishing installation")
        WebDriverWait(driver, WAIT_DELAY()).until(EC.element_to_be_clickable((By.NAME, "__wiz_services[]")))
        for service in driver.find_elements_by_name("__wiz_services[]"):
            service.click()
        driver.find_element_by_name("StepNext").click()
        WebDriverWait(driver, WAIT_DELAY() * 2).until(EC.element_to_be_clickable((By.NAME, "StepCancel")))

        driver.save_screenshot("installation.png")
        driver.quit()
    except Exception as exception:
        if hasattr(exception, "screen") and exception.screen:
            with open("error.png", "wb") as log:
                log.write(base64.decodebytes(exception.screen.encode()))
        else:
            driver.save_screenshot("error.png")
        with open("error.html", "w") as log:
            log.write(driver.page_source)
        raise

if __name__ == "__main__":
    main()
