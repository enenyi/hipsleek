#Compare old result with new result
#================SLEEK==========================
#================SLEEK==========================
echo "======= thrd1.slk ======"
diff test-cases/thrd1.res test-cases/thrd1.n

#================HIP==========================
#================HIP==========================
echo "======= motiv-example.ss  ======"
diff test-cases/motiv-example.res test-cases/motiv-example.n
echo "======= motiv-example2.ss  ======"
diff test-cases/motiv-example2.res test-cases/motiv-example2.n
#================BENCHMARK==========================
#================BENCHMARK==========================
