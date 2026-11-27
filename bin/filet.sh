if [ "${1:-}" = "T1" ]
then
  echo "          ---------------------------"
  echo "          FILET DE TEST AVEC T1/FASMG"
  echo "          ---------------------------"
else
  echo "          ---------------------------------------"
  echo "          FILET DE TEST AVEC TLALOC (TARGET_CODE)"
  echo "          ---------------------------------------"
fi

./comp_PREDEFS $1


echo ""
echo "          -----------------"
echo "          COMPILE ENUM_TEST"
echo "          -----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./enum_test.adb
  ./T1 BIND ./enum_test.adb
  cd ./ADA__LIB
  ./fasmg ENUM_TEST.fas ENUM_TEST
else
  ./TLALOC COMPILE ./enum_test.adb
  ./TLALOC BIND ./enum_test.adb
  ./TLALOC CODE ENUM_TEST
  cd ./ADA__LIB
fi

chmod u+x ./ENUM_TEST.x86exe
printf 'rouge\n' | ./ENUM_TEST.x86exe
cd ..


echo ""
echo "          ----------------------"
echo "          COMPILE DIRECT_IO_TEST"
echo "          ----------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./direct_io_test.adb
  ./T1 BIND ./direct_io_test.adb
  cd ./ADA__LIB
  ./fasmg DIRECT_IO_TEST.fas DIRECT_IO_TEST
else
  ./TLALOC COMPILE ./direct_io_test.adb
  ./TLALOC BIND ./direct_io_test.adb
  ./TLALOC CODE DIRECT_IO_TEST
  cd ./ADA__LIB
fi

chmod u+x DIRECT_IO_TEST.x86exe
./DIRECT_IO_TEST.x86exe
cd ..


echo ""
echo "          -------------------"
echo "          COMPILE SEQ_IO_TEST"
echo "          -------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./seq_io_test.adb
  ./T1 BIND ./seq_io_test.adb
  cd ./ADA__LIB
  ./fasmg SEQ_IO_TEST.fas SEQ_IO_TEST
else
  ./TLALOC COMPILE ./seq_io_test.adb
  ./TLALOC BIND ./seq_io_test.adb
  ./TLALOC CODE SEQ_IO_TEST
  cd ./ADA__LIB
fi

chmod u+x SEQ_IO_TEST.x86exe
./SEQ_IO_TEST.x86exe
cd ..


echo ""
echo "          ---------------------"
echo "          COMPILE TEST_CALENDAR"
echo "          ---------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./test_calendar.adb
  ./T1 BIND ./test_calendar.adb
  cd ./ADA__LIB
  ./fasmg TEST_CALENDAR.fas TEST_CALENDAR
else
  ./TLALOC COMPILE ./test_calendar.adb
  ./TLALOC BIND ./test_calendar.adb
  ./TLALOC CODE TEST_CALENDAR
  cd ./ADA__LIB
fi

chmod u+x TEST_CALENDAR.x86exe
./TEST_CALENDAR.x86exe
cd ..


echo ""
echo "          ------------------"
echo "          COMPILE FLOAT_TEST"
echo "          ------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./float_test.adb
  ./T1 BIND ./float_test.adb
   cd ./ADA__LIB
  ./fasmg FLOAT_TEST.fas FLOAT_TEST
else
  ./TLALOC COMPILE ./float_test.adb
  ./TLALOC BIND ./float_test.adb
  ./TLALOC CODE FLOAT_TEST
  cd ./ADA__LIB
fi

chmod u+x FLOAT_TEST.x86exe
./FLOAT_TEST.x86exe
cd ..


echo ""
echo "          ---------------------------"
echo "          COMPILE FLOAT_FIXED_IO_TEST"
echo "          ---------------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./float_fixed_io_test.adb
  ./T1 BIND ./float_fixed_io_test.adb
  cd ./ADA__LIB
  ./fasmg FLOAT_FIXED_IO_TEST.fas FLOAT_FIXED_IO_TEST
else
  ./TLALOC COMPILE ./float_fixed_io_test.adb
  ./TLALOC BIND ./float_fixed_io_test.adb
  ./TLALOC CODE FLOAT_FIXED_IO_TEST
  cd ./ADA__LIB
fi

chmod u+x FLOAT_FIXED_IO_TEST.x86exe
./FLOAT_FIXED_IO_TEST.x86exe
cd ..


echo ""
echo "          -------------------"
echo "          COMPILE ARRAY_TEST1"
echo "          -------------------"
if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./array_test1.ada
  ./T1 BIND ./array_test1.ada
  cd ./ADA__LIB
  ./fasmg ARRAY_TEST1.fas ARRAY_TEST1
else
  ./TLALOC COMPILE ./array_test1.ada
  ./TLALOC BIND ./array_test1.ada
  ./TLALOC CODE ARRAY_TEST1
  cd ./ADA__LIB
fi

chmod u+x ARRAY_TEST1.x86exe
./ARRAY_TEST1.x86exe
cd ..


echo ""
echo "          -------------------"
echo "          COMPILE ARRAY_TEST2"
echo "          -------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./array_test2.ada
  ./T1 BIND ./array_test2.ada
  cd ./ADA__LIB
  ./fasmg ARRAY_TEST2.fas ARRAY_TEST2
else
  ./TLALOC COMPILE ./array_test2.ada
  ./TLALOC BIND ./array_test2.ada
  ./TLALOC CODE ARRAY_TEST2
  cd ./ADA__LIB
fi

chmod u+x ARRAY_TEST2.x86exe
./ARRAY_TEST2.x86exe
cd ..


echo ""
echo "          -------------------"
echo "          COMPILE ARRAY_TEST3"
echo "          -------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./array_test3.ada
  ./T1 BIND ./array_test3.ada
  cd ./ADA__LIB
  ./fasmg ARRAY_TEST3.fas ARRAY_TEST3
else
  ./TLALOC COMPILE ./array_test3.ada
  ./TLALOC BIND ./array_test3.ada
  ./TLALOC CODE ARRAY_TEST3
  cd ./ADA__LIB
fi

chmod u+x ARRAY_TEST3.x86exe
./ARRAY_TEST3.x86exe
cd ..


echo ""
echo "          --------------------"
echo "          COMPILE REC_ARR_TEST"
echo "          --------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./rec_pack.ads
  ./T1 COMPILE ./rec_pack.adb
  ./T1 COMPILE ./rec_arr_test.adb
  ./T1 BIND ./rec_arr_test.adb
  cd ./ADA__LIB
  ./fasmg REC_ARR_TEST.fas REC_ARR_TEST
else
  ./TLALOC COMPILE ./rec_pack.ads
  ./TLALOC COMPILE ./rec_pack.adb
  ./TLALOC COMPILE ./rec_arr_test.adb
  ./TLALOC BIND ./rec_arr_test.adb
  ./TLALOC CODE REC_ARR_TEST
  cd ./ADA__LIB
fi

chmod u+x REC_ARR_TEST.x86exe
./REC_ARR_TEST.x86exe
cd ..


echo ""
echo "          -----------------"
echo "          COMPILE GOTO_TEST"
echo "          -----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./goto_test.adb
  ./T1 BIND ./goto_test.adb
  cd ./ADA__LIB
  ./fasmg GOTO_TEST.fas GOTO_TEST
else
  ./TLALOC COMPILE ./goto_test.adb
  ./TLALOC BIND ./goto_test.adb
  ./TLALOC CODE GOTO_TEST
  cd ./ADA__LIB
fi

chmod u+x GOTO_TEST.x86exe
./GOTO_TEST.x86exe
cd ..


echo ""
echo "          -----------------"
echo "          COMPILE CONV_DER1"
echo "          -----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./conv_der1.adb
  ./T1 BIND ./conv_der1.adb
  cd ./ADA__LIB
  ./fasmg CONV_DER1.fas CONV_DER1
else
  ./TLALOC COMPILE ./conv_der1.adb
  ./TLALOC BIND ./conv_der1.adb
  ./TLALOC CODE CONV_DER1
  cd ./ADA__LIB
fi

chmod u+x CONV_DER1.x86exe
./CONV_DER1.x86exe
cd ..


echo ""
echo "          -----------------"
echo "          COMPILE CASE_ST1"
echo "          -----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./case_st1.adb
  ./T1 BIND ./case_st1.adb
  cd ./ADA__LIB
  ./fasmg CASE_ST1.fas CASE_ST1
else
  ./TLALOC COMPILE ./case_st1.adb
  ./TLALOC BIND ./case_st1.adb
  ./TLALOC CODE CASE_ST1
  cd ./ADA__LIB
fi

chmod u+x CASE_ST1.x86exe
./CASE_ST1.x86exe
cd ..


echo ""
echo "          ---------------"
echo "          COMPILE ARRINI1"
echo "          ---------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./arrini1.adb
  ./T1 BIND ./arrini1.adb
  cd ./ADA__LIB
  ./fasmg ARRINI1.fas ARRINI1
else
  ./TLALOC COMPILE ./arrini1.adb
  ./TLALOC BIND ./arrini1.adb
  ./TLALOC CODE ARRINI1
  cd ./ADA__LIB
fi

chmod u+x ARRINI1.x86exe
./ARRINI1.x86exe
cd ..


echo ""
echo "          --------------"
echo "          COMPILE SLICE1"
echo "          --------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./slice1.adb
  ./T1 BIND ./slice1.adb
  cd ./ADA__LIB
  ./fasmg SLICE1.fas SLICE1
else
  ./TLALOC COMPILE ./slice1.adb
  ./TLALOC BIND ./slice1.adb
  ./TLALOC CODE SLICE1
  cd ./ADA__LIB
fi

chmod u+x SLICE1.x86exe
./SLICE1.x86exe
cd ..


echo ""
echo "          --------------"
echo "          COMPILE INSTF1"
echo "          --------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./instf1.adb
  ./T1 BIND ./instf1.adb
  cd ./ADA__LIB
  ./fasmg INSTF1.fas INSTF1
else
  ./TLALOC COMPILE ./instf1.adb
  ./TLALOC BIND ./instf1.adb
  ./TLALOC CODE INSTF1
  cd ./ADA__LIB
fi

chmod u+x INSTF1.x86exe
./INSTF1.x86exe
cd ..


echo ""
echo "          ----------------"
echo "          COMPILE ADDR_OV1"
echo "          ----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./addr_ov1.adb
  ./T1 BIND ./addr_ov1.adb
  cd ./ADA__LIB
  ./fasmg ADDR_OV1.fas ADDR_OV1
else
  ./TLALOC COMPILE ./addr_ov1.adb
  ./TLALOC BIND ./addr_ov1.adb
  ./TLALOC CODE ADDR_OV1
  cd ./ADA__LIB
fi

chmod u+x ADDR_OV1.x86exe
./ADDR_OV1.x86exe
cd ..


echo ""
echo "          ----------------"
echo "          COMPILE SLCONV1"
echo "          ----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./slconv1.adb
  ./T1 BIND ./slconv1.adb
  cd ./ADA__LIB
  ./fasmg SLCONV1.fas SLCONV1
else
  ./TLALOC COMPILE ./slconv1.adb
  ./TLALOC BIND ./slconv1.adb
  ./TLALOC CODE SLCONV1
  cd ./ADA__LIB
fi

chmod u+x SLCONV1.x86exe
./SLCONV1.x86exe
cd ..


echo ""
echo "          ----------------"
echo "          COMPILE LITAFF1"
echo "          ----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./litaff1.adb
  ./T1 BIND ./litaff1.adb
  cd ./ADA__LIB
  ./fasmg LITAFF1.fas LITAFF1
else
  ./TLALOC COMPILE ./litaff1.adb
  ./TLALOC BIND ./litaff1.adb
  ./TLALOC CODE LITAFF1
  cd ./ADA__LIB
fi

chmod u+x LITAFF1.x86exe
./LITAFF1.x86exe
cd ..


echo ""
echo "          ----------------"
echo "          COMPILE RETPKG1"
echo "          ----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./retpkg1.ada
  ./T1 BIND ./retpkg1.ada
  cd ./ADA__LIB
  ./fasmg RETPKG1.fas RETPKG1
else
  ./TLALOC COMPILE ./retpkg1.ada
  ./TLALOC BIND ./retpkg1.ada
  ./TLALOC CODE RETPKG1
  cd ./ADA__LIB
fi

chmod u+x RETPKG1.x86exe
./RETPKG1.x86exe
cd ..


echo ""
echo "          -------------------"
echo "          COMPILE AGGSTR_TEST"
echo "          -------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./aggstr_test.adb
  ./T1 BIND ./aggstr_test.adb
  cd ./ADA__LIB
  ./fasmg AGGSTR_TEST.fas AGGSTR_TEST
else
  ./TLALOC COMPILE ./aggstr_test.adb
  ./TLALOC BIND ./aggstr_test.adb
  ./TLALOC CODE AGGSTR_TEST
  cd ./ADA__LIB
fi

chmod u+x AGGSTR_TEST.x86exe
./AGGSTR_TEST.x86exe
cd ..


echo ""
echo "          ------------------"
echo "          COMPILE OPDEF_TEST"
echo "          ------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./opdef_test.adb
  ./T1 BIND ./opdef_test.adb
  cd ./ADA__LIB
  ./fasmg OPDEF_TEST.fas OPDEF_TEST
else
  ./TLALOC COMPILE ./opdef_test.adb
  ./TLALOC BIND ./opdef_test.adb
  ./TLALOC CODE OPDEF_TEST
  cd ./ADA__LIB
fi

chmod u+x OPDEF_TEST.x86exe
./OPDEF_TEST.x86exe
cd ..


echo ""
echo "          ------------------"
echo "          COMPILE PACKV_TEST"
echo "          ------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./packv_test.adb
  ./T1 BIND ./packv_test.adb
  cd ./ADA__LIB
  ./fasmg PACKV_TEST.fas PACKV_TEST
else
  ./TLALOC COMPILE ./packv_test.adb
  ./TLALOC BIND ./packv_test.adb
  ./TLALOC CODE PACKV_TEST
  cd ./ADA__LIB
fi

chmod u+x PACKV_TEST.x86exe
./PACKV_TEST.x86exe
cd ..


echo ""
echo "          ----------------"
echo "          COMPILE OPB_TEST"
echo "          ----------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./opb_test.adb
  ./T1 BIND ./opb_test.adb
  cd ./ADA__LIB
  ./fasmg OPB_TEST.fas OPB_TEST
else
  ./TLALOC COMPILE ./opb_test.adb
  ./TLALOC BIND ./opb_test.adb
  ./TLALOC CODE OPB_TEST
  cd ./ADA__LIB
fi

chmod u+x OPB_TEST.x86exe
./OPB_TEST.x86exe
cd ..


echo ""
echo "          ------------------------"
echo "          COMPILE GOTO_SELARG_TEST"
echo "          ------------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./goto_selarg_test.adb
  ./T1 BIND ./goto_selarg_test.adb
  cd ./ADA__LIB
  ./fasmg GOTO_SELARG_TEST.fas GOTO_SELARG_TEST
else
  ./TLALOC COMPILE ./goto_selarg_test.adb
  ./TLALOC BIND ./goto_selarg_test.adb
  ./TLALOC CODE GOTO_SELARG_TEST
  cd ./ADA__LIB
fi

chmod u+x GOTO_SELARG_TEST.x86exe
./GOTO_SELARG_TEST.x86exe
cd ..


echo ""
echo "          -------------------"
echo "          COMPILE INDARG_TEST"
echo "          -------------------"

if [ "${1:-}" = "T1" ]
then
  ./T1 COMPILE ./indarg_test.adb
  ./T1 BIND ./indarg_test.adb
  cd ./ADA__LIB
  ./fasmg INDARG_TEST.fas INDARG_TEST
else
  ./TLALOC COMPILE ./indarg_test.adb
  ./TLALOC BIND ./indarg_test.adb
  ./TLALOC CODE INDARG_TEST
  cd ./ADA__LIB
fi

chmod u+x INDARG_TEST.x86exe
./INDARG_TEST.x86exe
cd ..

echo "          --------------"
echo "          COMPILE TLALOC"
echo "          --------------"

if [ "${1:-}" = "T1" ]
then
  ./comp_TLALOC T1
else
  ./comp_TLALOC
fi

