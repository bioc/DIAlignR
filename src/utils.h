#ifndef UTILS_H
#define UTILS_H

#include <vector>

#ifdef USE_PRECONDITION
#define PRECONDITION(condition, message) assert(condition); // If you don't put the message, C++ will output the code.
#else
#define PRECONDITION(condition, message); // If USE_PRECONDITION is defined, compiler will replace calls with empty.
#endif

double getQuantile(std::vector<double> vec, double quantile);

#endif // UTILS_H
