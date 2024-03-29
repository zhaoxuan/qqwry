# @file = File.open('./qqwry.dat',"r")
# @index_first, @index_last = @file.read(8).unpack('L2')
# @index_total = (@index_last - @index_first)/7 + 1
require 'iconv'

class IpSearch
  def initialize(file='qqwry.dat')
    filename = file
    @file = File.open(filename,"r")
    @index_first, @index_last  = @file.read(8).unpack('L2')
    @index_total = (@index_last - @index_first)/7 + 1
    @location = {}
  end

  #把IP转换为长整形
  def ip2long(ip)
    long = 0
    ip.split(/\./).each_with_index do |b, i|
      long += b.to_i << 8*(3-i)
    end
    long
  end

  #读取偏移值
  def read_offset(position)
    @file.seek position
    chars = @file.read(3).unpack('C3')
    (chars[2]<<16) + (chars[1]<<8) + chars[0]
  end

  #读取记录中的4字节作为一个long值
  def read_long(position)
    @file.seek position
    @file.read(4).unpack('L')[0]
  end

  #读取模式信息，1和2为正常，其他值异常
  #position:字符串偏移量
  def read_mode(position)
    @file.seek position #前4位为IP值
    @file.read(1).unpack('C')[0]
  end

  #根据IP在索引中查找具体位置
  def find_str_offset(ip_long)
    offset_min,offset_max = @index_first,@index_last

    while offset_min <= offset_max
      offset_mid = offset_min + (offset_max - offset_min) / 14*7
      mid = read_long(offset_mid)

      if ip_long < mid
          offset_max = offset_mid - 7
      elsif ip_long == mid
          return read_offset(offset_mid+4)
      else
          offset_min = offset_mid + 7
      end
    end

    return read_offset(offset_max+4)
  end

  #读取字符串
  def read_str(position)
    @file.seek position
    str = []
    while c = @file.getc
      break if str.size > 60 #地址不会太长，防止有异常数据
      break if c == "\0"  #地址字符串以\0结尾
      str << c
    end
    str.join ''
  end

  #根据IP查找地址
  def find_ip_location(ip)
    offset = find_str_offset(ip2long(ip))#读取具体数据在记录区的偏移
    @location = {}
    case read_mode(offset+4)
    when 1
    str_offset = read_offset(offset+4+1) #读取字符串存储位置偏移（4是IP值，1是模式）
    if read_mode(str_offset)==2 then
      country_offset = read_offset(str_offset+1)
      @location[:country] = read_str country_offset
      @location[:area] = read_area(str_offset+4)
    else
      @location[:country] = read_str str_offset
      @location[:area] = read_area(@file.pos)
    end

    when 2
      str_offset = read_offset(offset+4+1) #读取字符串存储位置偏移（4是IP值，1是模式）
      @location[:country] = read_str(str_offset)
      @location[:area] = read_area(offset+8)
    else
      @location[:country] = read_str(offset)
      @location[:area] = read_str(@file.pos)
    end

    @location
  end

  #读取记录中的地址信息
  def read_area(position)
    mode = read_mode(position)
    if mode==1 || mode==2
      offset = read_offset(position+1)
      return '' if offset==0
      return read_str(offset)
    else
      return read_str(position)
    end
  end

  #取得国家，UTF8编码
  def country
    # Iconv.iconv('UTF-8//IGNORE','GB2312//IGNORE',@location[:country])
    # String.encode('UTF-8//IGNORE','GB2312//IGNORE',@location[:country])
    @location[:country].encode('UTF-8', :invalid => :replace, :replace => '').encode('UTF-8')
  end

  #取得地区，UTF8编码
  def area
    Iconv.iconv('UTF-8//IGNORE','GB2312//IGNORE',@location[:area])
    # String.encode('UTF-8//IGNORE','GB2312//IGNORE',@location[:area])
  end

  #取得国家，GB2312编码
  def country_gb
    @location[:country]
  end

  #取得地区，GB2312编码
  def area_gb
    @location[:area]
  end
end

#************************以下测试代码*****************
require 'debugger'
time_start = Time.now
list = %w[66.249.71.153 202.8.15.255.2 61.157.175.233 58.19.176.201 61.178.12.170 61.191.187.113 121.14.133.169 58.222.234.230 202.198.184.136 121.12.116.58 203.191.148.55]
is = IpSearch.new
100.times do |i|
  list.each do |ip|
    is.find_ip_location(ip)
    debugger
    puts is.country
    #puts is.area
    #puts '-'*50
  end
end

puts "total time:#{Time.now-time_start}"