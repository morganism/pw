#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'

require_relative '../lib/class_script'

options = OpenStruct.new 
options.number = 2
cs = ClassScript.new(options)
cs.print
