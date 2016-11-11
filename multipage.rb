require 'nokogiri'
require 'fileutils'
require 'shellwords'
require 'tempfile'

def multipage (sourceFileName, outputFileName)
  #load source file
  svgSource = Nokogiri::XML(File.read(sourceFileName))

  svgAllLayers = svgSource.xpath('//svg:g[@inkscape:groupmode="layer"]')

  tmpPdfFiles = []
  pageNumber = 1
  arePagesLeft = true

  while arePagesLeft do
    #copy svg temporarly
    svgToEdit = svgSource.clone

    layerName = "Page #{pageNumber}"

    #delete all layers that doesn't match
    #in detail : select all <g> that are inkscape layers (inkscape:groupmode="layer" attribute) and which doesn't have their layer name (inkscape:label attribute) beginning with the current page number.
    svgToEdit.xpath('//svg:g[@inkscape:groupmode="layer" and not(starts-with(@inkscape:label,"Page ' + pageNumber.to_s + '"))]').remove

    #only if there is still pages left
    unless svgToEdit.xpath('//svg:g[@inkscape:groupmode="layer"]').empty? then

      #force layer display
      begin#in case style attribute is not present
        svgToEdit.xpath('//svg:g[@inkscape:groupmode="layer"]').each do |svgLayer|
            svgLayer.attributes['style'].value = 'display:inline'
        end
      rescue
      end

      #give a name for temporary file
      tmpFileNameWithoutExt = "tmp_#{layerName}"

      # create a temporary svg file
      tmpSourceFile = Tempfile.new([tmpFileNameWithoutExt, '.svg'])
      File.write(tmpSourceFile.path, svgToEdit.to_xml)

      # create a temporary pdf file
      tmpPdfFile = Tempfile.new([tmpFileNameWithoutExt, '.pdf'])
      tmpPdfFiles.push(tmpPdfFile)

      #convert svg to pdf
      print "#{tmpPdfFile.path} produced.\n" if system "\ninkscape -C --export-pdf=#{tmpPdfFile.path.shellescape} --without-gui #{tmpSourceFile.path.shellescape}\n"

      #remove modified svg
      tmpSourceFile.close(true)

      #increment page number
      pageNumber += 1
    else
      arePagesLeft = false
    end
  end

  if tmpPdfFiles.size >= 1
    # merge pdfs and remove them
    pdfShellList = tmpPdfFiles.map { |file| file.path.shellescape }.join(" ")

    # ensure path exists
    FileUtils.mkpath(File.dirname(outputFileName))

    case
    when tmpPdfFiles.size == 1#just copy if only one file
      print "#{outputFileName} produced.\n" if system "cp #{tmpPdfFiles.first.path.shellescape} #{outputFileName.shellescape}"
    when tmpPdfFiles.size > 1#assemble if multiple file
      print "#{outputFileName} produced.\n" if system "pdfunite #{pdfShellList} #{outputFileName.shellescape}"
    end

    tmpPdfFiles.each { |tmpPdfFile| tmpPdfFile.close(true) }

    print "temporary files cleaned\n"
  end

end
