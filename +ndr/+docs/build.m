function build()
% ndr.docs.build - build the NDR markdown documentation from Matlab source
%
% Builds the ND$ documentation locally in $NDR-matlab/docs and updates the mkdocs-yml file
% in the $NDR-matlab directory.
%
% **Example**:
%   ndr.docs.build();
%

ndr.globals;

disp(['Now writing function reference...']);

ndr_path = ndr_globals.path.path;
ndr_docs = [ndr_path filesep 'docs' filesep 'reference']; % code reference path
ymlpath = 'reference';

disp(['Writing documents pass 1']);

out1 = vlt.docs.matlab2markdown(ndr_path,ndr_docs,ymlpath);
os = vlt.docs.markdownoutput2objectstruct(out1); % get object structures

disp(['Writing documents pass 2, with all links']);
out2 = vlt.docs.matlab2markdown(ndr_path,ndr_docs,ymlpath, os);

T = vlt.docs.mkdocsnavtext(out2,4);

ymlfile.references = [ndr_path filesep 'docs' filesep 'mkdocs-references.yml'];
ymlfile.start = [ndr_path filesep 'docs' filesep 'mkdocs-start.yml'];
ymlfile.end = [ndr_path filesep 'docs' filesep 'mkdocs-end.yml'];
ymlfile.main = [ndr_path filesep 'mkdocs.yml'];

vlt.file.str2text(ymlfile.references,T);

T0 = vlt.file.text2cellstr(ymlfile.start);
T1 = vlt.file.text2cellstr(ymlfile.references);
T2 = vlt.file.text2cellstr(ymlfile.end);

Tnew = cat(2,T0,T1,T2);

vlt.file.cellstr2text(ymlfile.main,Tnew);

