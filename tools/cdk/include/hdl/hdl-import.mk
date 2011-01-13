# This file should be included if a primitive library or core imports sources from elsewhere
ifndef OCPI_HDL_IMPORTS_DIR
$(error This primitive requires OCPI_HDL_IMPORTS_DIR to have a value, and it doesn't)
endif
.SECONDEXPANSION:

ImportsDir:=$(OutDir)imports
WImports:=$(wildcard $(Imports))
#$(info x$(WImports)y)
ifeq ($(strip $(WImports)),)
   $(error Wildcard imports set by the "Imports" variable did not expand to anything)
endif
$(foreach x,$(Imports),$(if $(wildcard $(x)),,$(error No files matching import name: "$(x)")))
$(foreach x,\
          $(ExcludeImports),\
	  $(if $(filter $(x),$(WImports) $(notdir $(WImports))),,\
	     $(error Excluded file $(x) is not in the Imports list)))
$(foreach i,\
	  $(WImports),\
	  $(if $(filter $(ExcludeImports) $(notdir $(ExcludeImports)),$(i)),,\
	    $(if $(realpath $(i)),,$(error Imported file $(i) does not exist.))))
NetImports:=\
  $(foreach i,\
	    $(WImports),\
            $(if $(filter $(ExcludeImports),$(i))$(filter $(notdir $(ExcludeImports)),$(notdir $(i))),,$(i)))
NetNames:=$(notdir $(NetImports))
$(foreach n,$(NetNames),$(if $(word 2,$(filter $(n),$(NetNames))),$(error Imported file $(n) is duplicated)))
#$(info im $(Imports))
#$(info wi $(WImports))
#$(info nn $(NetNames))
#$(info ni $(NetImports))
out:=$(strip $(shell if test ! -d $(ImportsDir); then \
		echo Making imports subdirectory to receive imported files for the $(LibName) primitive library. ; \
	        mkdir $(ImportsDir); \
		for i in $(NetImports); do cp $$i $(OutDir)imports; done; \
	     fi))
$(if $(out),$(info $(out)))
#$(info xxx $(shell echo $(ImportsDir)/*.[vV]))
#$(info yyy $(shell ls imports))
#$(info hdl-import1 csf $(CompiledSourceFiles))
#$(info hdl-import1a sf $(wildcard $(ImportsDir)/*))
#AAA:=$(sort $(wildcard $(ImportsDir)/*) $(CompiledSourceFiles))
#$(info aaa $(AAA))
CompiledSourceFiles:=$(sort $(CompiledSourceFiles) $(shell echo $(ImportsDir)/*.[vV]))
#$(info hdl-import2 csf $(CompiledSourceFiles))
#$(info sf is $(flavor CompiledSourceFiles) $(origin CompiledSourceFiles))
#$(info aaa is $(flavor AAA) $(origin AAA))