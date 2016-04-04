#Automatic Version number
#check this url for details
#https://www.altera.com/support/support-resources/design-examples/design-software/tcl/tcl-version-number.html
#you must add the following line to your QSF:
#set_global_assignment -name PRE_FLOW_SCRIPT_FILE quartus_sh:update_version.tcl


# Gets Date time stamp and converting to Hex
# The following command generates a date stamp of:
# %y Year without century (00 - 99)
# %m Month number (01 - 12)
# %d Day of month (01 - 31)
# %H Hour in 24-hour format (00 - 23) 

set str [clock format [clock seconds] -format {%y%m%d%H}]
set revision_number [format "%X" $str]

# Creates a register bank in a verilog file with the specified hex value
proc generate_verilog { hex_value } {

    set num_digits [string length $hex_value]
    set bit_width 32
    set high_index [expr { $bit_width - 1 } ]
    set reset_value [string repeat "0" $num_digits]

    if { [catch {
        set fh [open "version_reg.v" w ]
        puts $fh "module version_reg (clock, reset, data_out);"
        puts $fh "    input clock;"
        puts $fh "    input reset;"
        puts $fh "    output \[$high_index:0\] data_out;"
        puts $fh "    reg \[$high_index:0\] data_out;"
        puts $fh "    always @ (posedge clock or negedge reset) begin"
        puts $fh "        if (!reset)"
        puts $fh "            data_out <= ${bit_width}'h${reset_value};"
        puts $fh "        else"
        puts $fh "            data_out <= ${bit_width}'h${hex_value};"
        puts $fh "    end"
        puts $fh "endmodule"
        close $fh
    } res ] } {
        return -code error $res
    } else {
        return 1
    }
}

# This line accommodates script automation
foreach { flow project revision } $quartus(args) { break }


        # Call procedure to store the number
        if { [catch { generate_verilog $revision_number } res] } {
            post_message -type critical_warning \
               "Couldn't generate Verilog file. $res"
        } else {
            post_message "Successfully updated version number to\
                version 0x${revision_number}-$str"
        }
   
