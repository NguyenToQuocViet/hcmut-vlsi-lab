# ==============================================================================
# 1. ĐẶC TÍNH ĐIỆN ÁP TOÀN CỤC (GLOBAL VOLTAGE CONFIGURATION)
# Báo cho công cụ biết bank I/O đang chạy ở mức điện áp nào để tính toán 
# delay dòng điện chính xác.
# ==============================================================================
# set_property CFGBVS VCCO [current_design]
# set_property CONFIG_VOLTAGE 3.3 [current_design]

# ==============================================================================
# 2. RÀNG BUỘC XUNG NHỊP (CLOCK CONSTRAINTS)
# Ép hệ thống chạy ở 100MHz (10.0ns). Nếu muốn ép xung, đổi 10.000 thành 5.000
# ==============================================================================
create_clock -period 12.500 -name clk -waveform {0.000 6.250} [get_ports clk]

# Gán chân clk vào đúng vị trí vật lý của mạch dao động (Oscillator)
# E3 là chân Clock Capable của package CSG324.
# set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports clk]

# ==============================================================================
# 3. RÀNG BUỘC RESET (RESET CONSTRAINTS)
# ==============================================================================
# Gán rst_n vào một nút bấm cứng (Ví dụ chân C2)
# set_property -dict { PACKAGE_PIN C2    IOSTANDARD LVCMOS33 } [get_ports rst_n]

# KỸ THUẬT QUAN TRỌNG: Asynchronous Reset False Path
# Reset từ nút bấm con người là bất đồng bộ và rất chậm. Nếu không có dòng này,
# Vivado sẽ cố gắng ép đường dây reset từ I/O pin đến hàng nghìn FF phải chạy
# trong 10ns, gây cạn kiệt tài nguyên routing vô ích.
set_false_path -from [get_ports rst_n]

# ==============================================================================
# 4. RÀNG BUỘC CÁC CỔNG I/O KHÁC (ẢO HÓA)
# ==============================================================================
# Lưu ý: Các port AXI hiện tại chưa gán chân vật lý.
