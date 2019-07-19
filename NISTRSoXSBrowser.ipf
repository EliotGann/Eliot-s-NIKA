#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include "NI1_Loader"

function NR_Loaddir()
// this function loads the current directory, looking for all *primary.csv, listing all the * basenames
// along with the number of files
	svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	if(!svar_Exists(pname))
		NR_browse()
		svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	endif
	if(!svar_Exists(pname))
		print "no directory"
		return -1
	endif
	string filenames = sortlist(IndexedFile($pname, -1, ".csv"),";",4)
	string tiffnames = IndexedFile($pname, -1, ".tiff")
	string matchingtiffs
	if(strlen(filenames)<1)
		print "No txt files found in directory"
		return 0
	endif
	filenames = replacestring("-primary.csv",filenames,"")
	variable i
	String CurrentFolder=GetDataFolder(1)
	SetDataFolder root:Packages:NikaNISTRSoXS
	
	make /o/n=(itemsinlist(filenames),2) /t scanlist
	scanlist[][0]= stringfromlist(p,filenames)
	for(i=itemsinlist(filenames)-1;i>=0;i-=1)
		if(stringmatch(scanlist[i][0],"*baseline*"))
			deletePoints i,1,scanlist
		else
			matchingtiffs = listMatch(tiffnames,scanlist[i][0]+"*")
			scanlist[i][1] += num2str(itemsinlist(matchingtiffs)/2)
		endif
	endfor
	setdatafolder currentfolder
	
	//listbox scansLB,selrow=-1
	NR_loadprimary()
	
end

function NR_loadprimary()
// when choosing a primary.csv file, populates a list of promary values, a scrollable list of baseline values
// and displays a list of datapoints with their primary motors defining the name
	
	controlInfo scansLB
	variable /g scanrow = v_value
	wave /t scanlist = root:Packages:NikaNISTRSoXS:scanlist
	string basename = scanlist[scanrow][0]
	svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	if(!svar_Exists(pname))
		return -1
	endif
	
	String CurrentFolder=GetDataFolder(1)
	SetDataFolder root:Packages:NikaNISTRSoXS
	string /g basescanname = basename
	
	
	
	newdatafolder /o/s channels
	LoadWave/Q/O/J/D/A/K=0/P=$(pname)/W  basename+"-primary.csv"
	wave /z datawave = $(stringfromlist(0,S_waveNames))
	if(!waveexists(datawave))
		setdatafolder currentfolder
		return -1
	endif
	wave /t channellist = root:Packages:NikaNISTRSoXS:channellist
	wave channellistsel = root:Packages:NikaNISTRSoXS:channellistsel
	redimension /n=(itemsinlist(s_wavenames),2) channellist, channellistsel
	channellist[][1] = stringfromlist(p,s_wavenames)
	channellist[][0] = ""
	channellistsel[][0] = 32
	// pick out the channels to use for the sequence display
	wave /z en_energy
	wave /z seq_num
	
	if(!waveexists(en_energy))
		//not an energy scan, need to read something else .. what??
		print "can't find energy"
		setdatafolder currentfolder
	endif
	
	wave /t steplist = root:Packages:NikaNISTRSoXS:steplist
	wave steplistsel = root:Packages:NikaNISTRSoXS:steplistsel
	redimension /n=(dimsize(en_energy,0)) steplist, steplistsel
	steplist[] = num2str(seq_num[p]) + " - " + num2str(round(en_energy[p]*100)/100) + "eV"
	
	//populate the baseline and metadata lists
	
	wave /t mdlist = root:Packages:NikaNISTRSoXS:mdlist
	
	string jsonfiles= indexedfile($(pname),-1,".jsonl")
	variable jsonfound=0
	string metadatafilename
	string metadata=""
	if(strlen(jsonfiles) < 5)
		print "Currently can't load metadata json or jsonl file"
		mdlist = {"could not find metadata jsonl"}
	else
		jsonfound = 1
		metadatafilename = stringfromlist(0,greplist(jsonfiles,"^"+basename+".*jsonl"))
		metadata = addmetadatafromjson(pname,"institution",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"project_name",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"proposal_id",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"sample_name",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"sample_desc",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"sample_id",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"sample_set",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"user_name",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"user_id",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"notes",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"uid",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"dim1",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"dim2",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"dim3",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"chemical_formula",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"density",metadatafilename,metadata)
		metadata = addmetadatafromjson(pname,"project_desc",metadatafilename,metadata)
		metadata = replacestring(":",metadata,"  -  ")
		redimension /n=(itemsinlist(metadata)) mdlist
		mdlist[] = stringfromlist(p,metadata)
		
	endif	
	
	//baselines
	LoadWave/Q/O/J/D/n=baseline/K=0/P=$(pname)/m  basename+"-baseline.csv"
	wave /t baselines = $stringfromlist(0,S_waveNames)
	matrixtranspose baselines
	duplicate /o baselines, root:Packages:NikaNISTRSoXS:bllist
	
	NR_updateimageplot()
	
	setdatafolder currentfolder
end


Function NR_MetaBaseProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			if(tab==0)
				ListBox MetadataLB,disable=0
				ListBox baselineLB,disable=1
			elseif(tab==1)
				ListBox MetadataLB,disable=1
				ListBox baselineLB,disable=0
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function NR_datadispProc(tca) : TabControl
	STRUCT WMTabControlAction &tca

	switch( tca.eventCode )
		case 2: // mouse up
			Variable tab = tca.tab
			if(tab==0)
				setwindow NISTRSoXSBrowser#Graph2D,HIDE=1
				setwindow NISTRSoXSBrowser#Graph1D,HIDE=0
				SetVariable NR_Mindisp,disable=1
				SetVariable NR_Maxdisp,disable=1
				PopupMenu NR_Colorpop,disable=1
				CheckBox NR_logimg,disable=1
				Button NR_Autoscale,disable=1
			elseif(tab==1)
				setwindow NISTRSoXSBrowser#Graph2D,HIDE=0
				setwindow NISTRSoXSBrowser#Graph1D,HIDE=1
				SetVariable NR_Mindisp,disable=0
				SetVariable NR_Maxdisp,disable=0
				PopupMenu NR_Colorpop,disable=0
				CheckBox NR_logimg,disable=0
				Button NR_Autoscale,disable=0
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function NR_InitNISTRSoXS()
	dowindow /k NISTRSoXSBrowser
	NewPanel /W=(317,66,1673,931) /k=1 /N=NISTRSoXSBrowser as "NIST RSoXS data Browser"
	SetDrawLayer UserBack
	String CurrentFolder=GetDataFolder(1)
	newdatafolder /o/s root:Packages:NikaNISTRSoXS		
	string /g pathtodata, colortab
	if(strlen(colortab)<3)
		colortab = "Terrain"
	endif
	variable /g minval, maxval, logimage
	nvar /z scanrow
	if(!nvar_exists(scanrow))
		variable /g scanrow = -1
	endif
	wave /z/t scanlist, channellist, steplist, mdlist, bllist
	wave /z steplistsel, channellistsel
	if(!waveexists(scanlist))
		make /n=0/t scanlist
	endif
	if(!waveexists(steplist))
		make /n=0/t steplist
	endif
	if(!waveexists(channellist))
		make /n=0/t channellist
	endif
	if(!waveexists(channellistsel))
		make /n=0 channellistsel
	endif
	if(!waveexists(steplistsel))
		make /n=0 steplistsel
	endif
	if(!waveexists(mdlist))
		make /n=0/t mdlist
	endif
	if(!waveexists(bllist))
		make /n=0/t bllist
	endif
	make /o/n=2 /t scanlistboxcolumns = {"filenames","datapoints"}
	
	SetDataFolder $CurrentFolder
	
	ListBox ScansLB,pos={1.00,67.00},size={208.00,519.00},proc=NR_ScanListBoxProc
	ListBox ScansLB,listWave=root:Packages:NikaNISTRSoXS:scanlist,row= 7,mode= 1
	ListBox ScansLB,selRow= 28,widths={124,60},userColumnResize= 1
	ListBox ChannelLB,pos={217.00,67.00},size={251.00,139.00}
	ListBox ChannelLB,listWave=root:Packages:NikaNISTRSoXS:channellist,widths={15,250}
	ListBox ChannelLB,selWave=root:Packages:NikaNISTRSoXS:channellistsel,mode= 4,proc=NR_ChannelLBproc
	ListBox ScanStepLB,pos={217.00,272.00},size={251.00,377.00},proc=NR_ScanStepLBproc
	ListBox ScanStepLB,listWave=root:Packages:NikaNISTRSoXS:steplist
	ListBox ScanStepLB,selWave=root:Packages:NikaNISTRSoXS:steplistsel,row=scanrow
	ListBox ScanStepLB,mode= 9
	GroupBox group0,pos={214.00,258.00},size={259.00,397.00},title="Scan Steps"
	GroupBox group1,pos={214.00,52.00},size={259.00,207.00},title="Channels (check X-axis)"
	GroupBox scangroupo,pos={0.00,52.00},size={213.00,538.00},title="Scans"
	TabControl metabase,pos={1.00,591.00},size={207.00,270.00},proc=NR_MetaBaseProc
	TabControl metabase,tabLabel(0)="Metadata",tabLabel(1)="Baseline",value= 1
	ListBox MetadataLB,pos={4.00,617.00},size={198.00,239.00},disable=1
	ListBox MetadataLB,listWave=root:Packages:NikaNISTRSoXS:mdlist,row= 4,mode= 1
	ListBox MetadataLB,selRow=0
	ListBox baselineLB,pos={4.00,617.00},size={198.00,239.00}
	ListBox baselineLB,listWave=root:Packages:NikaNISTRSoXS:bllist
	ListBox baselineLB,widths={124,60,60},userColumnResize= 1
	Button Browsebut,pos={6.00,9.00},size={54.00,37.00},proc=NR_Browsebutfunc,title="Browse"
	TitleBox Pathdisp,pos={64.00,11.00},size={400.00,40.00},fSize=10,frame=5
	TitleBox Pathdisp,variable= root:Packages:NikaNISTRSoXS:pathtodata,fixedSize=1
	TabControl datadisp,pos={474.00,4.00},size={875.00,860.00},proc=NR_datadispProc
	TabControl datadisp,tabLabel(0)="1D data",tabLabel(1)="Images",value= 1
	Button LoadDarkBut,pos={216.00,720.00},size={125.00,34.00},proc=NR_NIKADarkbut,title="Load as Dark(s)"
	Button OpenMaskBut,pos={216.00,682.00},size={125.00,34.00},proc=NR_NIKAMaskbut,title="Open for Mask"
	Button BeamCenterBu,pos={344.00,682.00},size={125.00,34.00},proc=NR_NIKABCbut,title="Open for\rBeam Geometry"
	Button ConvSelBut,pos={344.00,721.00},size={125.00,34.00},proc=NR_NIKAbut,title="Convert Selection"
	Button QANTimportbut,pos={217.00,209.00},size={246.00,42.00},title="Import channels to\r QANT for analysis"
	GroupBox NIKAgroup,pos={214.00,662.00},size={259.00,98.00},title="NIKA Integration"
	Button NR_SAXSWAXSbut,pos={235.00,767.00},size={206.00,39.00},proc=NR_SWbutproc,title="SAXS images\r(click to toggle)"
	Button NR_SAXSWAXSbut,labelBack=(65535,65535,65535),fStyle=1,fColor=(0,0,20000)
	Button NR_SAXSWAXSbut,valueColor=(65535,65535,65535)
	SetVariable NR_Mindisp,pos={634.00,5.00},size={75.00,18.00},bodyWidth=50,proc=NR_ImageRangeChange,title="Min"
	SetVariable NR_Mindisp,limits={0,500000,1},value=minval
	SetVariable NR_Maxdisp,pos={716.00,6.00},size={76.00,18.00},bodyWidth=50,proc=NR_ImageRangeChange,title="Max"
	SetVariable NR_Maxdisp,limits={0,500000,1},value=maxval
	PopupMenu NR_Colorpop,pos={802.00,6.00},size={200.00,19.00},proc=NR_colorpopproc
	PopupMenu NR_Colorpop,mode=8,value= #"\"*COLORTABLEPOPNONAMES*\""	
	CheckBox NR_logimg,pos={1012.00,6.00},size={33.00,15.00},title="log",value=logimage,proc=NR_logimagebutproc,variable=logimage
	Button NR_Autoscale,pos={1069.00,6.00},size={68.00,15.00},proc=NR_autoscalebut,title="Autoscale"
	
	Display/W=(481,28,1344,860)/HOST=# /HIDE=1 
	RenameWindow #,Graph1D
	SetActiveSubwindow ##
	Display/W=(481,28,1344,860)/HOST=# 
	RenameWindow #,Graph2D
	SetActiveSubwindow ##
End

Function NR_Browsebutfunc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	switch( ba.eventCode )
		case 2: // mouse up
			NR_browse()
			NR_loaddir()
			break
	endswitch
	return 0
End

function NR_browse()
	String CurrentFolder=GetDataFolder(1)
	SetDataFolder root:Packages:NikaNISTRSoXS
	svar pathtodata
	NewPath/O/m="path for txt files" Path_NISTRSoXS			// This will put up a dialog
	if (V_flag == 0)
		string /g pathname
		pathname = "Path_NISTRSoXS"
		PathInfo Path_NISTRSoXS
		pathtodata = s_path
	endif
	SetDataFolder $CurrentFolder
end


Function NR_ScanListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba
	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	switch( lba.eventCode )
		case 4: // cell selection
		case 5: // cell selection plus shift key
			NR_loadprimary()
			break
	endswitch
	return 0
End



Function NR_SWbutproc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			string currentdatafolder = getdatafolder(1)
			setdatafolder root:Packages:NIKANISTRSoXS
			variable /g saxsorwaxs 
			saxsorwaxs = abs(saxsorwaxs-1)
			if(saxsorwaxs)
				button NR_SAXSWAXSbut fColor=(0,0,20000),title="SAXS images\r(click to toggle)",valueColor=(65535,65535,65535)
			else
				button NR_SAXSWAXSbut fColor=(1,26214,0),title="WAXS images\r(click to toggle)",valueColor=(0,0,0)
			endif
			NR_updateimageplot()
		case -1: // control being killed
			break
	endswitch

	return 0
End

function NR_updateimageplot([autoscale])
	variable autoscale
	autoscale = paramisDefault(autoscale)? 0 : autoscale
	wave selwave = root:Packages:NikaNISTRSoXS:steplistsel
	variable i, num 
	duplicate /free selwave, tempwave
	tempwave = selwave[p]? 1 : 0
	num = sum(tempwave)
	NR_MakeImagePlots(num)
	string listofsteps = ""
	for(i=0;i<dimsize(selwave,0);i+=1)
		if(selwave[i])
			listofsteps = addlistitem(num2str(i),listofsteps)
		endif
	endfor
	NR_loadimages(listofsteps, autoscale=autoscale)

end

function NR_MakeImagePlots(num)
	variable num
	variable numx, numy
	//481,28,1344,860
	//863,832
	string currentfolder = getdatafolder(1)
	setdatafolder root:Packages:NIKANISTRSoXS
	wave /z/t imagenames
	variable i
	if(waveexists(imagenames))
		for(i=0;i<dimsize(imagenames,0);i+=1)
			killwindow /z NISTRSoXSBrowser#Graph2D#$imagenames[i]
		endfor
	endif
	make /o/n=(num) /t imagenames
	
	
	if(num< 3)
			numy = 1
	elseif(num < 7)
			numy = 2
	elseif(num < 13)
			numy = 3
	elseif(num < 21)
			numy = 4
	elseif(num < 31)
			numy = 5
	elseif(num < 43)
			numy = 6
	elseif(num < 57)
			numy = 7
	elseif(num < 73)
			numy = 8
	elseif(num < 91)
			numy = 9
	else
		numy=10
	endif
	numx = ceil(num/numy)
	
	variable sizex, sizey
	sizex = floor(863 / numx)
	sizey = floor(832 / numy)
	
	variable xloc=0, yloc=0
	variable imnum = 0
	imagenames = "NR_image"+num2str(p)
	for(yloc=0;yloc<numy;yloc+=1)
		for(xloc=0;xloc<numx;xloc+=1)
			Display/W=(sizex*xloc,sizey*yloc,sizex*(xloc+1),sizey*(yloc+1))/HOST=NISTRSoXSBrowser#Graph2D /n=$imagenames[imnum]
			imnum+=1
			if(imnum>=num)
				break
			endif
		endfor
		if(imnum>=num)
			break
		endif
	endfor
	
	
end

Function NR_ScanStepLBproc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			NR_updateimageplot()
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

function NR_loadimages(listofsteps,[autoscale])
	string listofsteps
	variable autoscale
	autoscale = paramisDefault(autoscale)? 0 : autoscale
	listofsteps = sortlist(listofsteps,";",2)
	string currentfolder =getdatafolder(1)
	setdatafolder root:Packages:NIKANISTRSoXS
	svar basescanname
	nvar saxsorwaxs
	nvar /z leftmin
	nvar /z leftmax
	nvar /z botmin
	nvar /z botmax
	svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	wave /t imagenames
	wave /t steplist
	killdatafolder /z images
	newdatafolder /o/s images
	string tiffnames = IndexedFile($pname, -1, ".tiff")
	string matchingtiffs = listMatch(tiffnames,basescanname+"*")
	string tifffilename
	
	nvar /z minval = root:Packages:NikaNISTRSoXS:minval
	nvar /z maxval = root:Packages:NikaNISTRSoXS:maxval
	
	variable minv, maxv, totmaxv = 0, totminv = 5e10
	variable i
	for(i=0;i<itemsinlist(listofsteps);i+=1)
		if(saxsorwaxs)
			tifffilename = stringfromlist(0,listMatch(matchingtiffs,"*saxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		else
			tifffilename = stringfromlist(0,listMatch(matchingtiffs,"*waxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		endif
		if(strlen(tifffilename)<4)
			print "Could not find image to display"
		else
			ImageLoad/P=$(pname)/T=tiff/O/N=$("image"+num2str(i)) tifffilename
			wave image = $("image"+num2str(i))
			appendimage /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] image
			ModifyGraph /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] margin=1,nticks=0,standoff=0
			ModifyImage /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] ''#0 log=1,ctab= {*,*,Terrain,0}
			TextBox /w=NISTRSoXSBrowser#Graph2D#$imagenames[i]/S=0/F=0 steplist[str2num(stringfromlist(i,listofsteps))]
			minv = wavemin(image)
			maxv = wavemax(image)
			if(minv<totminv)
				totminv = minv
			endif
			if(maxv>totmaxv)
				totmaxv = maxv
			endif
		endif
	endfor
	if(autoscale)
		setaxis /A /w=NISTRSoXSBrowser#Graph2D#$imagenames[0]
		doupdate
		getaxis /w=NISTRSoXSBrowser#Graph2D#$imagenames[0] left
		leftmin = v_min
		leftmax = v_max
		getaxis /w=NISTRSoXSBrowser#Graph2D#$imagenames[0] bottom
		botmin = v_min
		botmax = v_max
		minval = totminv
		maxval = totmaxv
	else
		if(totminv > minval)
			minval = totminv
		endif
		if(totmaxv < maxval)
			maxval = totmaxv
		endif
	endif
	
	NR_updateimages()
	
	setdatafolder currentfolder
end

Function NR_ImageRangeChange(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			NR_updateimages()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


Function NR_colorpopproc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			svar /z colortab = root:Packages:NikaNISTRSoXS:colortab
			if(svar_exists(colortab))
				colortab = popStr
				NR_updateimages()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

function NR_updateimages()
	svar /z colortab = root:Packages:NikaNISTRSoXS:colortab
	nvar /z minval = root:Packages:NikaNISTRSoXS:minval
	nvar /z maxval = root:Packages:NikaNISTRSoXS:maxval
	nvar /z logimage = root:Packages:NikaNISTRSoXS:logimage
	nvar /z leftmin = root:Packages:NikaNISTRSoXS:leftmin
	nvar /z leftmax = root:Packages:NikaNISTRSoXS:leftmax
	nvar /z botmin = root:Packages:NikaNISTRSoXS:botmin
	nvar /z botmax = root:Packages:NikaNISTRSoXS:botmax
	wave /z/t imagenames  = root:Packages:NikaNISTRSoXS:imagenames
	setwindow NISTRSoXSBrowser,hook(syncaxes)=$"" 
	if(waveexists(imagenames) && svar_exists(colortab) && nvar_exists(minval) && nvar_exists(maxval) && nvar_exists(logimage))
		variable i
		for(i=0;i<dimsize(imagenames,0);i+=1)
			
			ModifyImage /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] ''#0 log=(logimage),ctab= {minval,maxval,$colortab,0}
			setaxis /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] left, leftmin, leftmax
			setaxis /w=NISTRSoXSBrowser#Graph2D#$imagenames[i] bottom, botmin, botmax
			
		endfor
	endif
	setwindow NISTRSoXSBrowser,hook(syncaxes)=NR_axishook
end
	

Function NR_logimagebutproc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			NR_updateimageplot()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function NR_axishook(s)
	STRUCT WMWinHookStruct &s
	Variable hookResult = 0
	//print s.eventCode
	switch(s.eventCode)
		case 4:
			break
		case 11:
			GetWindow $s.winName activeSW
			if(!stringmatch(s_value,"*NR_image*"))
				break
			endif
		case 6:
		case 8: // modified
			nvar /z leftmin = root:Packages:NikaNISTRSoXS:leftmin
			nvar /z leftmax = root:Packages:NikaNISTRSoXS:leftmax
			nvar /z botmin = root:Packages:NikaNISTRSoXS:botmin
			nvar /z botmax = root:Packages:NikaNISTRSoXS:botmax
			GetWindow $s.winName activeSW
			string subwindow = s_value
			print subwindow
			getaxis /w=$(subwindow) left
			leftmin = v_min
			leftmax = v_max
			getaxis /w=$(subwindow) bottom
			botmin = v_min
			botmax = v_max
			NR_updateimages()
			hookresult = 1
			break
		default:
			//print s.eventcode	
	endswitch
	return hookResult // 0 if nothing done, else 1
End

Function NR_autoscalebut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			// click code here
			NR_updateimageplot(autoscale=1)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End



Function NR_ChannelLBproc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			NR_plotchannels()
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			string x_axis
			if(selwave[row] & 16)
				//checkbox on
				x_axis = listwave[row][1]
				variable i
				for(i=0;i<dimsize(selwave,0);i+=1)
					if(i!=row && selwave[i] & 16)
						selwave[i] -=16
					endif
				endfor
			else
				for(i=0;i<dimsize(selwave,0);i+=1)
					if(i!=0 && selwave[i] & 16)
						selwave[i] -=16
					endif
					if(!(selwave[0] & 16))
						selwave[0] += 16
					endif
				endfor
				x_axis = listwave[0][1]
			endif
			string currenfolder = getdatafolder(1)
			setdatafolder root:Packages:NikaNISTRSoXS:
			string /g x_axisname = x_axis
			NR_plotchannels(fresh=1)
			break
	endswitch

	return 0
End


function NR_plotchannels([fresh])
	variable fresh
	fresh = paramisdefault(fresh)? 0 : fresh
	wave /t listwave = root:Packages:NikaNISTRSoXS:channellist
	wave selwave = root:Packages:NikaNISTRSoXS:channellistsel
	
	make /free /n=(dimsize(selwave,0)) selected
	selected = selwave[p] & 1
	variable num = sum(selected)
	string channels2plot = ""
	variable j
	for(j=0;j<dimsize(selwave,0);j+=1)
		if(selected[j])
			channels2plot = addlistitem(listwave[j][1],channels2plot)
		endif
	endfor
	
	string plottedchannels = tracenamelist("NISTRSoXSBrowser#Graph1D",";",1)
	string channeltoplot
	string plottedchannel
	svar /z x_axisname = root:Packages:NikaNISTRSoXS:x_axisname
	if(!svar_exists(x_axisname))
		print "Cannot plot anything until an X-axis is chosen"
		return 0
	endif
	
	variable i
	for(i=itemsinlist(plottedchannels)-1;i>=0;i-=1)
		plottedchannel = stringfromlist(i,plottedchannels)
		if(fresh || (whichlistitem(plottedchannel,channels2plot)<0))
			removefromgraph /z /w=NISTRSoXSBrowser#Graph1D $plottedchannel
		endif
	endfor
	
	plottedchannels = tracenamelist("NISTRSoXSBrowser#Graph1D",";",1)
	
	
	wave xwave = root:Packages:NikaNISTRSoXS:channels:$x_axisname
	for(i=0;i<itemsinlist(channels2plot);i+=1)
		channeltoplot = stringfromlist(i,channels2plot)
		if(stringmatch(channeltoplot,x_axisname) || whichlistitem(channeltoplot,plottedchannels)>=0)
			continue
		endif
		wave channel = root:Packages:NikaNISTRSoXS:channels:$channeltoplot
		appendtograph /w=NISTRSoXSBrowser#Graph1D channel vs xwave
	endfor
	NR_ColorTraces("SpectrumBlack","NISTRSoXSBrowser#Graph1D")
end

function NR_ColorTraces(Colortabname,Graphname)
	string colortabname, graphname
	
	if(cmpstr(graphName,"")==0)
		graphname = WinName(0, 1)
	endif
	if (strlen(graphName) == 0)
		return -1
	endif

	Variable numTraces =itemsinlist(TraceNameList(graphName,";",1))
	if (numTraces <= 0)
		return -1
	endif
	variable numtracesden=numtraces
	if( numTraces < 2 )
		numTracesden= 2	// avoid divide by zero, use just the first color for 1 trace
	endif

	ColorTab2Wave $colortabname
	wave RGB = M_colors
	Variable numRows= DimSize(rgb,0)
	Variable red, green, blue
	Variable i, index
	for(i=0; i<numTraces; i+=1)
		index = round(i/(numTracesden-1) * (numRows*2/3-1))	// spread entire color range over all traces.
		ModifyGraph/w=$graphName rgb[i]=(rgb[index][0], rgb[index][1], rgb[index][2])
	endfor
end




function NR_convertpathtonika([main,mask,dark,beamcenter])
	variable mask,dark,beamcenter,main
	svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	PathInfo $pname
	if(main)
		NI1A_Convert2Dto1DMainPanel()
		svar SampleNameMatchStr = root:Packages:Convert2Dto1D:SampleNameMatchStr
		SampleNameMatchStr = ""
		popupmenu Select2DDataType win=NI1A_Convert2Dto1DPanel, popmatch="BS_Suitcase_Tiff"
		newpath /O/Q/Z Convert2Dto1DDataPath S_path
		SVAR MainPathInfoStr=root:Packages:Convert2Dto1D:MainPathInfoStr
		MainPathInfoStr=S_path
		TitleBox PathInfoStrt, win =NI1A_Convert2Dto1DPanel, variable=MainPathInfoStr
		NI1A_UpdateDataListBox()	
	endif
	if(mask)
		NI1M_CreateMask()
		newpath /O/Q/Z Convert2Dto1DMaskPath S_path
		popupmenu CCDFileExtension win=NI1M_ImageROIPanel, popmatch="BS_Suitcase_Tiff"
		SVAR CCDFileExtension=root:Packages:Convert2Dto1D:CCDFileExtension
		CCDFileExtension = "BS_Suitcase_Tiff"
		NI1M_UpdateMaskListBox()
	endif
	if(dark)
		NI1A_Convert2Dto1DMainPanel()
		newpath /O/Q/Z Convert2Dto1DEmptyDarkPath S_path
		popupmenu SelectBlank2DDataType win=NI1A_Convert2Dto1DPanel, popmatch="BS_Suitcase_Tiff"
		nVAR usedarkfield=root:Packages:Convert2Dto1D:UseDarkField
		usedarkfield=1
		SVAR BlankFileExtension=root:Packages:Convert2Dto1D:BlankFileExtension
		BlankFileExtension = "BS_Suitcase_Tiff"
		SVAR DataFileExtension=root:Packages:Convert2Dto1D:DataFileExtension
		DataFileExtension = "BS_Suitcase_Tiff"
		svar EmptyDarkNameMatchStr = root:Packages:Convert2Dto1D:EmptyDarkNameMatchStr
		EmptyDarkNameMatchStr = ""
		NI1A_UpdateEmptyDarkListBox()	
	endif
	if(beamcenter)
		NI1_CreateBmCntrFile()
		newpath /O/Q/Z Convert2Dto1DBmCntrPath S_path
		popupmenu BmCntrFileType win=NI1_CreateBmCntrFieldPanel, popmatch="BS_Suitcase_Tiff"
		SVAR BmCntrFileType=root:Packages:Convert2Dto1D:BmCntrFileType
		BmCntrFileType = "BS_Suitcase_Tiff"
		SVAR BCPathInfoStr=root:Packages:Convert2Dto1D:BCPathInfoStr
		BCPathInfoStr=S_Path
		NI1BC_UpdateBmCntrListBox()
	endif
end


function /t NR_getfilenames()
	string currentfolder =getdatafolder(1)
	setdatafolder root:Packages:NIKANISTRSoXS
	wave selwave = root:Packages:NikaNISTRSoXS:steplistsel
	variable i
	string listofsteps = ""
	for(i=0;i<dimsize(selwave,0);i+=1)
		if(selwave[i])
			listofsteps = addlistitem(num2str(i),listofsteps)
		endif
	endfor

	svar basescanname
	nvar saxsorwaxs
	svar /z pname = root:Packages:NikaNISTRSoXS:pathname
	wave /t steplist
	killdatafolder /z images
	newdatafolder /o/s images
	string tiffnames = IndexedFile($pname, -1, ".tiff")
	string matchingtiffs = listMatch(tiffnames,basescanname+"*")
	string filenames = ""
	string tifffilename = ""
	for(i=0;i<itemsinlist(listofsteps);i+=1)
		if(saxsorwaxs)
			tifffilename = stringfromlist(0,listMatch(tiffnames,basescanname+"*saxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		else
			tifffilename = stringfromlist(0,listMatch(tiffnames,basescanname+"*waxs*-"+stringfromlist(i,listofsteps)+".tiff"))
		endif
		filenames = addlistitem(tifffilename,filenames)
	endfor
	return filenames
	
end

Function NR_NIKABCbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up			
			string filelist = NR_getfilenames()
			NR_loadforbeamcenteringinNIKA(stringfromlist(0,filelist))
			break
	endswitch
	return 0
End
Function NR_NIKADarkbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string filelist = NR_getfilenames()
			NR_loadasdarkinnika(filelist)
			break
	endswitch
	return 0
End
Function NR_NIKAMaskbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string filelist = NR_getfilenames()
			NR_loadformaskinnika(stringfromlist(0,filelist))
			break
	endswitch

	return 0
End

Function NR_NIKAbut(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			string filelist = NR_getfilenames()
			NR_convertnikafilelistsel(filelist)
			break
	endswitch

	return 0
End


function NR_loadasdarkinnika(filenamelist)
	string filenamelist
	string filename
	NR_convertpathtonika(dark=1)
	doupdate
	Wave/T  ListOffilenames=root:Packages:Convert2Dto1D:ListOf2DEmptyData
	variable i=0
	for(i=0;i<itemsinlist(filenamelist);i+=1)
		filename = stringfromlist(i,filenamelist)
		FindValue /TEXT=filename /TXOP=6 /Z ListOffilenames
		if(v_value>=0)
			listbox Select2DMaskDarkWave win=NI1A_Convert2Dto1DPanel, selrow=v_value 
			doupdate
			NI1A_LoadEmptyOrDark("Dark")
		endif
	endfor
end

function NR_loadformaskinnika(filename)
	string filename
	NR_convertpathtonika(mask=1)
	doupdate
	Wave/T  ListOffilenames=root:Packages:Convert2Dto1D:ListOfCCDDataInCCDPath
	variable i
	FindValue /TEXT=filename /TXOP=6 /Z ListOffilenames
	if(v_value>=0)
		listbox CCDDataSelection win=NI1M_ImageROIPanel, selrow=v_value 
		doupdate
		NI1M_MaskCreateImage() 
	endif
end

function NR_loadforbeamcenteringinNIKA(filename)
	string filename
	NR_convertpathtonika(beamcenter=1)
	doupdate
	Wave/T  ListOffilenames=root:Packages:Convert2Dto1D:ListOfCCDDataInBmCntrPath
	FindValue /TEXT=filename /TXOP=6 /Z ListOffilenames
	if(v_value>=0)
		listbox CCDDataSelection win=NI1_CreateBmCntrFieldPanel, selrow=v_value 
		doupdate
		NI1BC_BmCntrCreateImage()
		NVAR BMMaxCircleRadius=root:Packages:Convert2Dto1D:BMMaxCircleRadius
		Wave BmCntrFieldImg=root:Packages:Convert2Dto1D:BmCntrCCDImg 
		BMMaxCircleRadius=sqrt(DimSize(BmCntrFieldImg, 0 )^2 + DimSize(BmCntrFieldImg, 1 )^2)
		Slider BMHelpCircleRadius,limits={1,BMMaxCircleRadius,0}, win=NI1_CreateBmCntrFieldPanel
		SetVariable BMHelpCircleRadiusV,limits={1,BMMaxCircleRadius,0}, win=NI1_CreateBmCntrFieldPanel
		NVAR BMImageRangeMinLimit= root:Packages:Convert2Dto1D:BMImageRangeMinLimit
		NVAR BMImageRangeMaxLimit = root:Packages:Convert2Dto1D:BMImageRangeMaxLimit
		Slider ImageRangeMin,limits={BMImageRangeMinLimit,BMImageRangeMaxLimit,0}, win=NI1_CreateBmCntrFieldPanel
		Slider ImageRangeMax,limits={BMImageRangeMinLimit,BMImageRangeMaxLimit,0}, win=NI1_CreateBmCntrFieldPanel
		NI1BC_DisplayHelpCircle()
		NI1BC_DisplayMask()
		TabControl BmCntrTab, value=0, win=NI1_CreateBmCntrFieldPanel
		showinfo /w=CCDImageForBmCntr
	endif
end

function NR_convertnikafilelistsel(filenamelist)
	string filenamelist
	NR_convertpathtonika(main=1)
	doupdate
	Wave/T  ListOf2DSampleData=root:Packages:Convert2Dto1D:ListOf2DSampleData
	Wave ListOf2DSampleDataNumbers=root:Packages:Convert2Dto1D:ListOf2DSampleDataNumbers
	ListOf2DSampleDataNumbers = 0
	string filename = stringfromlist(0,filenamelist)
	variable i
	for(i=0;i<itemsinlist(filenamelist);i+=1)
		filename = stringfromlist(i,filenamelist)
		FindValue /TEXT=filename /TXOP=6 /Z ListOf2DSampleData
		if(v_value>=0)
			ListOf2DSampleDataNumbers[v_value] = 1
		endif
	endfor
	doupdate
	NI1A_CheckParametersForConv()
	//set selections for using RAW/Converted data...
	NVAR LineProfileUseRAW=root:Packages:Convert2Dto1D:LineProfileUseRAW
	NVAR LineProfileUseCorrData=root:Packages:Convert2Dto1D:LineProfileUseCorrData
	NVAR SectorsUseRAWData=root:Packages:Convert2Dto1D:SectorsUseRAWData
	NVAR SectorsUseCorrData=root:Packages:Convert2Dto1D:SectorsUseCorrData
	LineProfileUseRAW=0
	LineProfileUseCorrData=1
	SectorsUseRAWData=0
	SectorsUseCorrData=1
	//selection done
	NI1A_LoadManyDataSetsForConv()
end