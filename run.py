#!/usr/bin/env python3

from selenium import webdriver
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.common.by import By
from selenium.webdriver.support.select import Select
from selenium.webdriver.firefox.options import Options

from pprint import pp

import operator
import functools

# Fold Left and Right in Python <https://www.burgaud.com/foldl-foldr-python>
foldl = lambda func, acc, xs: functools.reduce(func, xs, acc)

import time

pages = ["https://www.vprok.ru/catalog/4248/myaso?attr%5Brate%5D%5B%5D=0&sort=price_asc",
         "https://www.vprok.ru/catalog/4248/myaso?attr%5Brate%5D%5B%5D=0&sort=price_asc&page=2"]

# Like in Guile Scheme
def pk(value):
    pp(value)
    return value

def main():
    options = Options()
    options.headless = False
    driver = webdriver.Firefox(options=options)

    def parse(page):
        driver.get(page)
        return list(map(lambda product: product.text.split("\n"), driver.find_elements_by_class_name("xf-catalog__item")))

    pk(foldl(operator.add, [], (list(map(parse, pages)))))
    driver.quit()

if __name__ == "__main__":
    main()
