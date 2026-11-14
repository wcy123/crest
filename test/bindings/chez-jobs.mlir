// The Chez build takes its number of jobs from CREST_CHEZ_JOBS (the cores of the machine by default), and does not have
// a number in its text (make -j8) (check-chez-jobs.py).
//
// RUN: python3 %S/check-chez-jobs.py %S/../..

module {}
