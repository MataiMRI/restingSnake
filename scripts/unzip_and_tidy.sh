datadir=$1
projectdir=$2

echo
echo "Switching to data directory at path: " $datadir
cd $datadir
mkdir -p ./dicom
echo
echo "Moving the following .zip folders to dicom subdirectory:"
ls *.zip
mv *.zip ./dicom
echo
echo "Unzipping the following folders:"
cd dicom
ls *.zip
unzip "*.zip"
echo
echo "Removing redundant .zip folders"
echo
rm -r *.zip
n_ses=$(ls | wc -l)
echo "Data available for " $n_ses " sessions"
ls
echo
echo "Switching back to project directory at path: " $projectdir
echo
cd $projectdir
