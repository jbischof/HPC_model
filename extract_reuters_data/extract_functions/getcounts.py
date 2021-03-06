
#!/usr/bin/env python

"""
Extracts n-gram and generalized bigram counts from the Reuters RCV2 dataset.

Author: Saketh Bhamidipati (svbhamid@fas.harvard.edu)
Date: September 7, 2010

Requires: nltk, python >= 2.6

"""

import xml.etree.ElementTree as ET

import nltk.util
import nltk.tokenize
import nltk.corpus

import string

from itertools import combinations

# these lists map the codes to their zero-indexed positions in each list for use in, say, R data
region_codes = ["AARCT","ABDBI","AFGH","AFRICA","AJMN","ALADI","ALB","ALG","AMSAM","ANDEAN","ANDO","ANGOL","ANGUIL","ANTA","ANZUS","APEC","ARABST","ARG","ARMEN","ARMHG","ARUBA","ASEAN","ASIA","AUSNZ","AUST","AUSTR","AZERB","BAH","BAHRN","BALTST","BANDH","BARB","BELG","BELZ","BENIN","BENLUX","BERM","BHUTAN","BIOT","BOL","BOTS","BRAZ","BRUNEI","BSHZG","BUL","BURMA","BURUN","BVI","BYELRS","CACCM","CAFR","CAM","CAMER","CANA","CANI","CARCOM","CARIB","CASIA","CAYI","CEAFR","CHAD","CHIL","CHINA","COL","COMOR","COMWH","CONGO","COOKIS","COSR","CRTIA","CUBA","CURAC","CVI","CYPR","CZREP","DEN","DEVGCO","DIEGO","DOMA","DOMR","DUBAI","EAFR","EASIA","EASTIS","ECOWAS","ECU","EEC","EEUR","EFTA","EGYPT","ELSAL","EQGNA","ERTRA","ESTNIA","ETHPA","EUR","EUREA","FAEROE","FALK","FEAST","FESMIC","FGNA","FIJI","FIN","FPDT","FPOLY","FRA","FUJH","GABON","GAMB","GCC","GFIVE","GFR","GHANA","GIB","GREECE","GREENL","GREN","GRGIA","GSEVEN","GTEN","GUAD","GUAM","GUAT","GUBI","GULFST","GUREP","GUY","HAIT","HKONG","HON","HUNG","ICEL","ICST","INDIA","INDOCH","INDON","INDSUB","IRAN","IRAQ","IRE","ISLAM","ISRAEL","ITALY","JAMA","JAP","JORDAN","KAMPA","KAZK","KENYA","KIRB","KIRGH","KUWAIT","LAM","LAOS","LATV","LEBAN","LESOT","LIBER","LIBYA","LIECHT","LITH","LUX","MACAO","MAH","MALAG","MALAW","MALAY","MALDR","MALI","MALTA","MARQ","MAURTN","MAURTS","MCDNIA","MEAST","MED","MEX","MOLDV","MONAC","MONGLA","MONT","MOROC","MOZAM","MRCSL","NAFR","NAFTA","NAM","NAMIB","NANT","NATO","NAURU","NEPAL","NETH","NEWCAL","NICG","NIGEA","NIGER","NIUE","NKOREA","NOMARI","NORFIS","NORW","NZ","OAMS","OAPEC","OAU","OCEANA","OECD","OILEX","OMAN","OPEC","PACIS","PACRM","PAKIS","PALAU","PANA","PAPNG","PARA","PERU","PHLNS","PITCIS","POL","PORL","PST","PTAESA","PURI","QATAR","RAKH","REUNI","ROM","RUSS","RWANDA","SAARAB","SAARC","SADCC","SAFR","SAM","SASIA","SCAND","SEASIA","SELA","SENEG","SEYCH","SHAJH","SILEN","SINGP","SKIT","SKOREA","SLUC","SLVAK","SLVNIA","SMARNO","SOLIL","SOMAL","SOUAFR","SPAIN","SPSAH","SRILAN","STHEL","STPM","SUDAN","SURM","SVIN","SWAZD","SWED","SWITZ","SYRIA","TADZK","TAI","TAIWAN","TANZA","TCAI","THAIL","THDWLD","TIMOR","TOGO","TOKLAU","TONGA","TRSCUN","TRTO","TUNIS","TURK","TURKM","TVLU","UAE","UAQ","UGANDA","UK","UKRN","UN","UPVOLA","URU","USA","USAAK","USAAL","USAAR","USAAZ","USACA","USACO","USACT","USADC","USADE","USAFL","USAGA","USAHI","USAIA","USAID","USAIL","USAIN","USAKS","USAKY","USALA","USAMA","USAMD","USAME","USAMI","USAMN","USAMO","USAMS","USAMT","USANC","USAND","USANE","USANH","USANJ","USANM","USANV","USANY","USANYC","USAOK","USAOR","USAPA","USARI","USASC","USASD","USATN","USATX","USAUT","USAVA","USAVT","USAWA","USAWI","USAWV","USAWY","USSR","UZBK","VANU","VCAN","VEN","VI","VIETN","WAFR","WALLIS","WASIA","WEEC","WEIND","WESTW","WEUR","WORLD","WSOMOA","YEMAR","YUG","ZAIRE","ZAMBIA","ZIMBAB"]
industry_codes = ["I0","I00","I000","I0000","I00000","I01","I010","I0100","I01000","I01001","I0100105","I0100107","I0100119","I0100121","I0100124","I0100128","I0100132","I0100136","I0100137","I0100138","I0100141","I0100142","I0100144","I0100145","I01002","I0100206","I0100216","I0100223","I02","I020","I0200","I02000","I03","I030","I0300","I03000","I1","I10","I100","I1000","I10000","I11","I110","I1100","I11000","I12","I120","I1200","I12000","I13","I130","I1300","I13000","I1300002","I1300003","I1300013","I1300014","I14","I140","I1400","I14000","I15","I150","I1500","I15000","I16","I160","I1600","I16000","I161","I1610","I16100","I16101","I1610107","I1610109","I162","I1620","I16200","I163","I1630","I16300","I17","I170","I1700","I17000","I2","I20","I200","I2000","I20000","I21","I210","I2100","I21000","I22","I220","I2200","I22000","I221","I2210","I22100","I222","I2220","I22200","I223","I2230","I22300","I224","I2240","I22400","I2245","I22450","I2246","I22460","I2247","I22470","I22471","I22472","I23","I230","I2300","I23000","I24","I240","I2400","I24000","I241","I2410","I24100","I242","I2420","I24200","I243","I2430","I24300","I244","I2440","I24400","I245","I2450","I24500","I246","I2460","I24600","I247","I2470","I24700","I2479","I24794","I248","I2480","I24800","I25","I250","I2500","I25000","I251","I2510","I25100","I2511","I25110","I2512","I25120","I2513","I25130","I2514","I25140","I2516","I25160","I255","I2551","I25510","I2552","I25520","I256","I2562","I25620","I2565","I25650","I2567","I25670","I2568","I25680","I257","I2570","I25700","I258","I2580","I25800","I26","I260","I2600","I26000","I3","I30","I300","I3000","I30000","I31","I310","I3100","I31000","I32","I320","I3200","I32000","I3204","I32040","I3205","I32050","I321","I3210","I32100","I322","I3220","I32200","I32220","I323","I3230","I32300","I324","I3244","I32440","I3245","I32450","I325","I3251","I32510","I3254","I32540","I3255","I32550","I326","I3260","I32600","I327","I32700","I3275","I32751","I32752","I32753","I32754","I32755","I328","I3281","I32810","I3283","I32830","I3284","I32840","I3285","I32851","I32852","I3287","I32870","I329","I3290","I32900","I33","I330","I33000","I3301","I33010","I3302","I33020","I3302003","I3302004","I3302013","I3302015","I3302017","I3302018","I3302019","I330202","I3302020","I3302021","I3302022","I3303","I33030","I34","I340","I3400","I34000","I341","I3410","I34100","I342","I3420","I34200","I343","I3432","I34320","I3433","I34330","I3434","I34340","I3435","I34350","I344","I3440","I34400","I3441","I34410","I3442","I34420","I3443","I34430","I3444","I34440","I345","I3450","I3452","I34520","I3453","I34531","I34532","I3454","I34540","I346","I3460","I34600","I347","I3470","I34700","I35","I350","I3500","I35000","I351","I3510","I35101","I35102","I352","I3520","I35200","I353","I3530","I35300","I36","I361","I3610","I36100","I36101","I36102","I36103","I362","I3620","I36200","I363","I3630","I36300","I364","I3640","I36400","I3640002","I3640007","I364001","I3640010","I3640026","I3640029","I364003","I3640030","I3640045","I3640046","I3640047","I3640048","I37","I370","I3700","I37000","I371","I3710","I37100","I372","I3720","I37200","I373","I3730","I37300","I3733","I37330","I374","I3740","I37400","I4","I40","I400","I4000","I40000","I41","I410","I4100","I41000","I411","I4110","I41100","I412","I4120","I41200","I4122","I41220","I4123","I41230","I413","I4130","I41300","I414","I4140","I41400","I415","I4150","I41500","I416","I4160","I41600","I418","I4180","I41800","I419","I4190","I41900","I42","I420","I4200","I42000","I421","I4210","I42100","I422","I4221","I42210","I4222","I42220","I423","I4239","I42390","I424","I4240","I42400","I426","I4260","I42600","I427","I4270","I42700","I428","I4280","I42800","I429","I4290","I42900","I43","I430","I4300","I43000","I44","I440","I4400","I44000","I45","I450","I4500","I45000","I451","I4510","I45100","I453","I4530","I45300","I455","I4550","I45500","I456","I4560","I45600","I46","I460","I4600","I46000","I467","I4670","I46700","I47","I470","I4700","I47000","I471","I4710","I47100","I47101","I472","I4720","I47200","I475","I4750","I47500","I4751","I47510","I4752","I47520","I47521","I4752105","I4753","I47530","I48","I480","I4800","I48000","I481","I4810","I48100","I4811","I48110","I483","I4830","I48300","I49","I491","I4910","I49100","I492","I4920","I49200","I493","I4930","I49300","I494","I4941","I49410","I4942","I49420","I495","I4954","I49540","I5","I50","I500","I5000","I50000","I501","I5010","I50100","I5010022","I5010023","I5010024","I5010025","I5010027","I5010028","I5010029","I5010031","I502","I5020","I50200","I5020002","I5020006","I5020008","I5020011","I5020017","I5020022","I5020028","I502003","I5020030","I5020032","I5020039","I5020041","I5020043","I5020044","I5020045","I5020047","I502005","I5020050","I5020051","I503","I5030","I50300","I504","I5040","I50400","I6","I60","I600","I6000","I60000","I61","I610","I6100","I61000","I63","I630","I6300","I63000","I64","I640","I6400","I64000","I641","I6410","I64100","I642","I6420","I64200","I643","I6430","I64300","I645","I6450","I64500","I646","I6460","I64600","I647","I6470","I64700","I648","I6480","I64800","I65","I650","I6500","I65000","I651","I6510","I65100","I652","I6520","I65200","I653","I6530","I65300","I654","I6540","I65400","I6540005","I6540011","I654003","I6540030","I656","I6560","I65600","I6560002","I6560003","I6560011","I66","I660","I6600","I66000","I661","I6610","I66100","I662","I6620","I66200","I665","I6650","I66500","I67","I670","I6700","I67000","I7","I70","I700","I7000","I70000","I71","I710","I7100","I71000","I72","I721","I7210","I72101","I72102","I722","I7220","I72200","I723","I7230","I72300","I726","I7260","I72603","I74","I740","I7400","I74000","I75","I750","I7500","I75000","I751","I7510","I75100","I76","I763","I7630","I76300","I764","I7640","I76400","I77","I770","I7700","I77001","I77002","I77003","I79","I790","I7901","I79010","I7902","I79020","I8","I80","I800","I8000","I80000","I81","I810","I8100","I81000","I814","I8140","I81400","I81401","I81402","I81403","I815","I8150","I81501","I8150103","I8150106","I8150108","I815011","I8150110","I81502","I8150203","I8150206","I8150211","I8150214","I8150216","I82","I820","I8200","I82000","I82001","I82002","I82003","I8200316","I8200318","I83","I83000","I831","I8310","I83100","I832","I8320","I83200","I834","I8340","I83400","I835","I8350","I83500","I836","I8360","I83600","I837","I8370","I83700","I838","I8380","I83800","I839","I83900","I8394","I83940","I8394007","I8395","I83951","I83952","I8395205","I83953","I83954","I8395416","I8395419","I8395448","I8395449","I8395451","I8396","I83960","I84","I840","I8400","I84000","I841","I8410","I84100","I842","I8420","I84200","I843","I8430","I84300","I846","I8460","I84600","I848","I8480","I84800","I84801","I84802","I84803","I84804","I8480401","I848041","I8480410","I85","I850","I8500","I85000","I8500005","I8500011","I8500021","I8500029","I8500031","I9","I90","I900","I9000","I90000","I92","I921","I92100","I9211","I92110","I9212","I92120","I923","I9230","I92300","I95","I951","I9510","I95100","I97","I971","I9710","I97100","I974","I9740","I97400","I9741","I97411","I9741102","I9741105","I9741109","I974111","I9741110","I9741112","I97412","I979","I9791","I97911","I97912","I98","I981","I9810","I98100","I9999","I99999"]
topic_codes = ["1POL","2ECO","3SPO","4GEN","6INS","7RSK","8YDB","9BNX","ADS10","BNW14","BRP11","C11","C12","C13","C14","C15","C151","C1511","C152","C16","C17","C171","C172","C173","C174","C18","C181","C182","C183","C21","C22","C23","C24","C31","C311","C312","C313","C32","C33","C331","C34","C41","C411","C42","CCAT","E11","E12","E121","E13","E131","E132","E14","E141","E142","E143","E21","E211","E212","E31","E311","E312","E313","E41","E411","E51","E511","E512","E513","E61","E71","ECAT","ENT12","G11","G111","G112","G113","G12","G13","G131","G14","G15","G151","G152","G153","G154","G155","G156","G157","G158","G159","GCAT","GCRIM","GDEF","GDIP","GDIS","GEDU","GENT","GENV","GFAS","GHEA","GJOB","GMIL","GOBIT","GODD","GPOL","GPRO","GREL","GSCI","GSPO","GTOUR","GVIO","GVOTE","GWEA","GWELF","M11","M12","M13","M131","M132","M14","M141","M142","M143","MCAT","MEUR","PRB13"]

def region_code_id(region_code):
    """
    Converts a Reuters region code into a numeric id. Returns -1
    if not found.

    (See codes/region_codes.txt.)
    """
    try:
        return region_codes.index(region_code)
    except ValueError:
        return -1

def industry_code_id(industry_code):
    """
    Converts a Reuters region code into a numeric id. Returns -1
    if not found.

    (See codes/industry_codes.txt.)
    """
    try:
        return industry_codes.index(industry_code)
    except ValueError:
        return -1

def topic_code_id(topic_code):
    """
    Converts a Reuters topic code into a numeric id. Returns -1
    if not found.

    (See codes/topic_codes.txt.)
    """
    try:
        return topic_codes.index(topic_code)
    except ValueError:
        return -1

class ReutersArticle(object):
    """Wrapper for a news article."""
    def __init__(self, article_xml, n=1, is_stemmed=False):
        """
        Constructs an article from a string containing a Reuters
        article in XML (e.g. 19960820/2286newsML.xml).
        
        Also computes the n-grams (n is by default 1) and generalized
        bigrams in the article after tokenization and (optionally)
        stemming.
        """

        try: self.tree = ET.fromstring(article_xml)
        except ValueError:
            print article_xml
        
        try: self.title = self.tree.find('title').text
        except: self.title = ''
        try: self.headline = self.tree.find('headline').text
        except: self.headline = ''
        try:
            self.byline = self.tree.find('byline').text
        except:
            self.byline = ''
        
        self.paragraphs = self.tree.findall('text/p')
        try: self.text = '\n'.join(p.text for p in self.paragraphs)
        except: self.text = ''
        
        self.document = '\n'.join([self.title, self.byline, self.text])
        """ 
        The document is the collection of tokens we wish to include in
        our estimation problem (e.g. title, text).
        
        I joined title, headline, byline, and text into the document,
        but if you wish to analyze some subset of these, simply change
        the instantiation.
        """
        
        self.codeses = self.tree.findall(".//codes")
        try:
            self.region_codes = filter(lambda codes: 'countries' in codes.attrib['class'], self.codeses)[0]
            """
            In this line, I arbitrarily code a document's region as
            the first listed code. This is a strong assumption that
            should be tweaked in later investigation, here as well as
            for the industry and topic codes.
            """
            self.region_code = self.region_codes.find('code').attrib['code']
        except:
            self.region_code = None
        
        try:
            self.industry_codes = filter(lambda codes: 'industries' in codes.attrib['class'], self.codeses)[0]
            self.industry_code = self.industry_codes.find('code').attrib['code']
        except:
            self.industry_code = None
            
        try:
            self.topic_codes = filter(lambda codes: 'topics' in codes.attrib['class'], self.codeses)[0]
            self.topic_code = self.topic_codes.find('code').attrib['code']
        except:
	    self.topic_codes = None
	    self.topic_code = None
            
        self.region_code_id = region_code_id(self.region_code)
        self.industry_code_id = industry_code_id(self.industry_code)
        self.topic_code_id = topic_code_id(self.topic_code)

        self.tokens = self.__tokenize(is_useful=None)
        #self.tokens = self.__tokenize(is_useful=self.__is_not_stopword)
        self.ngrams = self.__get_ngrams(n)
        self.generalized_bigrams = self.__get_generalized_bigrams()
        
    def __tokenize(self, is_useful=None):
        """
        Returns a list of useful tokens in the document, where the notion of
        usefulness is passed in as a predicate.
        """
        unfiltered_tokens = nltk.tokenize.word_tokenize(self.document)
        if is_useful:
            return filter(is_useful, unfiltered_tokens)
        else:
            return unfiltered_tokens
    
    def __is_not_stopword(self, token):
        return token.isalpha() and token not in nltk.corpus.stopwords.words('english')
    
    def __get_ngrams(self, n):
        """
        Compute n-gram counts.
        """
        return nltk.util.ngrams(self.tokens, n)

    def __get_generalized_bigrams(self):
        """
        Returns a list of generalized bigrams in the document as an iterable.
        """
        return combinations(self.tokens, 2)

#if __name__ == "__main__":
    ## simple use
    #article_xml = open('19960820/2286newsML.xml').read()
    #article = ReutersArticle(article_xml)
    
    #print article.ngrams # where n is by default 1, so unigrams
    #print article.generalized_bigrams

    #print article.region_code
    #print article.region_code_id    
    #print article.industry_code
    #print article.industry_code_id
    #print article.topic_code
    #print article.topic_code_id
