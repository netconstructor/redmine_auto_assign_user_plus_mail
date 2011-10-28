require 'iconv'

class String
  def to_ascii
    ascii = "acelnoszzACELNOSZZ"
    cep = "\271\346\352\263\361\363\234\277\237\245\306\312\243\321\323\214\257\217"
    s = Iconv.new("cp1250", "UTF-8").iconv(self)
    s.tr!(cep, ascii)
    return (s.length==0) ? self : s
  end
end